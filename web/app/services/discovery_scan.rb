# frozen_string_literal: true

# Runs and caches discovery scans for an edition corpus.
class DiscoveryScan
  Params = Struct.new(
    :mode, :divisible_by, :scope, :bucket, :min_count, :min_group_size, :match_by,
    keyword_init: true
  )

  DivisibleRow = Struct.new(:scope, :token_norm, :token_raw, :count, :divisible_by, keyword_init: true)

  EqualCountRow = Struct.new(:scope, :count, :words, :match_by, keyword_init: true)
  WordEntry = Struct.new(:token_norm, :token_raws, keyword_init: true)

  MODES = %w[divisible equal_count].freeze
  MATCH_BY = %w[norm spelling].freeze
  SCOPES = %w[whole_bible ot nt].freeze
  BUCKETS = %w[default verse_text psalm_heading colophon].freeze

  def self.normalize(raw)
    mode = raw[:mode].to_s
    divisible_by = raw[:divisible_by].to_i
    min_count = raw[:min_count].to_i
    min_group_size = raw[:min_group_size].to_i
    scope = raw[:scope].to_s
    bucket = raw[:bucket].to_s

    Params.new(
      mode: MODES.include?(mode) ? mode : "divisible",
      divisible_by: divisible_by.positive? ? divisible_by : 7,
      scope: SCOPES.include?(scope) ? scope : "whole_bible",
      bucket: BUCKETS.include?(bucket) ? bucket : "default",
      min_count: min_count.positive? ? min_count : 7,
      min_group_size: min_group_size >= 2 ? min_group_size : 2,
      match_by: MATCH_BY.include?(raw[:match_by].to_s) ? raw[:match_by].to_s : "norm"
    )
  end

  def self.run(edition, params, force: false)
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
    else
      compute_divisible(edition, params)
    end
  end

  def self.compute_divisible(edition, params)
    scope_sym = params.scope.to_sym
    bucket = params.bucket == "default" ? :default : params.bucket

    Inamen::DivisibleBySevenScan.scan(
      edition.db,
      divisible_by: params.divisible_by,
      scope: scope_sym,
      bucket: bucket,
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
    scope_sym = params.scope.to_sym
    bucket = params.bucket == "default" ? :default : params.bucket

    Inamen::EqualCountScan.scan(
      edition.db,
      scope: scope_sym,
      bucket: bucket,
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

  def self.cached?(edition, params)
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

  def self.cache_key_for(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    [
      "discovery_scan/v3",
      p.mode,
      p.match_by,
      edition.edition_id,
      edition.checksum_prefix,
      Inamen::CorpusStore::INDEXER_REVISION,
      p.divisible_by,
      p.scope,
      p.bucket,
      p.min_count,
      p.min_group_size
    ]
  end
end
