# frozen_string_literal: true

require "digest"

# Runs and caches discovery scans for an edition corpus.
class DiscoveryScan
  Params = Struct.new(
    :mode, :divisible_by, :search_selection, :min_count, :min_group_size, :match_by, :query_terms,
    keyword_init: true
  )

  DivisibleRow = Struct.new(:scope, :token_norm, :token_raw, :count, :divisible_by, keyword_init: true)

  EqualCountRow = Struct.new(:scope, :count, :words, :match_by, keyword_init: true)
  WordEntry = Struct.new(:token_norm, :token_raws, keyword_init: true)

  WordCountRow = Struct.new(:pattern, :case_sensitive, :count, :wildcard, :scope, :spellings, keyword_init: true)

  MODES = %w[divisible equal_count word_count].freeze
  MATCH_BY = %w[norm spelling].freeze

  def self.normalize(raw)
    mode = raw[:mode].to_s
    divisible_by = raw[:divisible_by].to_i
    min_count = raw[:min_count].to_i
    min_group_size = raw[:min_group_size].to_i

    search_selection =
      if raw[:search_selection]
        Inamen::SearchSelection.from_params(raw[:search_selection])
      elsif raw[:scope] || raw[:bucket]
        Inamen::SearchSelection.from_legacy(
          scope: raw[:scope].presence || "whole_bible",
          bucket: raw[:bucket].presence || "default"
        )
      else
        Inamen::SearchSelection.default
      end

    Params.new(
      mode: MODES.include?(mode) ? mode : "word_count",
      divisible_by: divisible_by.positive? ? divisible_by : 7,
      search_selection: search_selection,
      min_count: min_count.positive? ? min_count : 7,
      min_group_size: min_group_size >= 2 ? min_group_size : 2,
      match_by: MATCH_BY.include?(raw[:match_by].to_s) ? raw[:match_by].to_s : "norm",
      query_terms: raw[:query_terms].to_s
    )
  end

  def self.run(edition, params, force: false)
    return [] if params.mode == "word_count" && params.query_terms.blank?

    key = cache_key_for(edition, params)
    Rails.cache.delete(key) if force

    Rails.cache.fetch(key, expires_in: 7.days) do
      compute(edition, params)
    end
  end

  def self.compute(edition, params)
    case params.mode
    when "equal_count"
      compute_equal_count(edition, params)
    when "word_count"
      compute_word_count(edition, params)
    else
      compute_divisible(edition, params)
    end
  end

  def self.compute_divisible(edition, params)
    Inamen::DivisibleBySevenScan.scan(
      edition.db,
      divisible_by: params.divisible_by,
      search_selection: params.search_selection,
      min_count: params.min_count
    ).map do |row|
      DivisibleRow.new(
        scope: row.scope,
        token_norm: row.token_norm,
        token_raw: row.token_raw,
        count: row.count,
        divisible_by: row.divisible_by
      )
    end
  end

  def self.compute_equal_count(edition, params)
    Inamen::EqualCountScan.scan(
      edition.db,
      search_selection: params.search_selection,
      min_count: params.min_count,
      min_group_size: params.min_group_size,
      match_by: params.match_by
    ).map do |group|
      EqualCountRow.new(
        scope: group.scope,
        count: group.count,
        match_by: group.match_by.to_s,
        words: group.words.map do |word|
          WordEntry.new(token_norm: word.token_norm, token_raws: word.token_raws)
        end
      )
    end
  end

  def self.compute_word_count(edition, params)
    return [] if params.query_terms.blank?

    terms = Inamen::TokenQuery.parse_terms(params.query_terms)

    Inamen::TokenQuery.scan(
      edition.db,
      terms: terms,
      search_selection: params.search_selection
    ).map do |row|
      WordCountRow.new(
        pattern: row.pattern,
        case_sensitive: row.case_sensitive,
        count: row.count,
        wildcard: row.wildcard,
        scope: row.scope,
        spellings: row.spellings
      )
    end
  end

  def self.cached?(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    return false if p.mode == "word_count" && p.query_terms.blank?

    key = cache_key_for(edition, params)
    return false unless Rails.cache.exist?(key)

    value = Rails.cache.read(key)
    !value.nil?
  rescue TypeError
    Rails.cache.delete(key)
    false
  end

  def self.read_cached(edition, params)
    Rails.cache.read(cache_key_for(edition, params))
  rescue TypeError
    clear_cache!(edition, params)
    nil
  end

  def self.clear_cache!(edition, params)
    Rails.cache.delete(cache_key_for(edition, params))
  end

  def self.running?(edition, params)
    Rails.cache.exist?(running_key_for(edition, params))
  end

  def self.running_key_for(edition, params)
    "#{cache_key_for(edition, params)}/running"
  end

  def self.job_payload(params)
    p = params.is_a?(Params) ? params : normalize(params)
    {
      mode: p.mode,
      divisible_by: p.divisible_by,
      search_selection: p.search_selection.to_h.merge(submitted: "1"),
      min_count: p.min_count,
      min_group_size: p.min_group_size,
      match_by: p.match_by,
      query_terms: p.query_terms
    }
  end

  def self.cache_key_for(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    terms_digest =
      if p.mode == "word_count" && p.query_terms.present?
        Digest::SHA256.hexdigest(p.query_terms)[0, 16]
      end
    [
      "discovery_scan/v5",
      p.mode,
      p.match_by,
      terms_digest,
      edition.edition_id,
      edition.checksum_prefix,
      Inamen::CorpusStore::INDEXER_REVISION,
      p.divisible_by,
      p.search_selection.cache_key,
      p.min_count,
      p.min_group_size
    ]
  end
end
