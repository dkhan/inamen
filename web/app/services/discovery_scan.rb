# frozen_string_literal: true

require "digest"

# Runs and caches discovery scans for an edition corpus.
class DiscoveryScan
  Params = Struct.new(
    :mode, :divisible_by, :search_selection, :min_count, :min_group_size, :match_by, :query_terms,
    :from_feature,
    keyword_init: true
  )

  DivisibleRow = Struct.new(:scope, :token_norm, :token_raw, :count, :divisible_by, keyword_init: true)

  EqualCountRow = Struct.new(:scope, :count, :words, :match_by, keyword_init: true)
  WordEntry = Struct.new(:token_norm, :token_raws, keyword_init: true)

  WordCountRow = Struct.new(:pattern, :case_sensitive, :count, :wildcard, :scope, :spellings, :exclude, :overlap,
                            keyword_init: true)

  MODES = %w[divisible equal_count word_count file_stats].freeze
  MATCH_BY = %w[norm spelling].freeze

  PhraseEntry = Struct.new(:phrase, :case_sensitive, :exclude, :disabled, keyword_init: true)

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

    query_terms = query_terms_from_raw(raw)

    Params.new(
      mode: MODES.include?(mode) ? mode : "word_count",
      divisible_by: divisible_by.positive? ? divisible_by : 7,
      search_selection: search_selection,
      min_count: min_count.positive? ? min_count : 7,
      min_group_size: min_group_size >= 2 ? min_group_size : 2,
      match_by: MATCH_BY.include?(raw[:match_by].to_s) ? raw[:match_by].to_s : "norm",
      query_terms: query_terms,
      from_feature: raw[:from_feature].presence
    )
  end

  def self.query_terms_from_raw(raw)
    if raw[:search_phrases].present?
      query_terms_from_phrases(raw[:search_phrases])
    else
      raw[:query_terms].to_s
    end
  end

  def self.phrase_entries_from_params(raw_phrases)
    entries = phrase_hashes(raw_phrases).map do |entry|
      PhraseEntry.new(
        phrase: entry[:phrase].to_s,
        case_sensitive: ActiveModel::Type::Boolean.new.cast(entry[:case_sensitive]),
        exclude: ActiveModel::Type::Boolean.new.cast(entry[:exclude]),
        disabled: ActiveModel::Type::Boolean.new.cast(entry[:disabled])
      )
    end
    entries.presence || [PhraseEntry.new(phrase: "", case_sensitive: false, exclude: false, disabled: false)]
  end

  def self.phrase_entries_from_query_terms(text)
    entries = text.to_s.each_line.filter_map do |line|
      attrs = Inamen::TokenPattern.parse_query_line(line)
      next unless attrs

      PhraseEntry.new(
        phrase: attrs[:pattern],
        case_sensitive: attrs[:case_sensitive],
        exclude: attrs[:exclude],
        disabled: attrs[:disabled]
      )
    end
    entries.presence || [PhraseEntry.new(phrase: "", case_sensitive: false, exclude: false, disabled: false)]
  end

  def self.query_terms_from_phrases(raw_phrases)
    phrase_hashes(raw_phrases).filter_map do |entry|
      phrase = entry[:phrase].to_s.strip
      next if phrase.empty?

      case_sensitive = ActiveModel::Type::Boolean.new.cast(entry[:case_sensitive])
      exclude = ActiveModel::Type::Boolean.new.cast(entry[:exclude])
      disabled = ActiveModel::Type::Boolean.new.cast(entry[:disabled])
      line = phrase
      line += "|cs" if case_sensitive
      line += "|exclude" if exclude
      line += "|disabled" if disabled
      line
    end.join("\n")
  end

  def self.enabled_search_terms?(query_terms)
    query_terms.to_s.each_line.any? do |line|
      attrs = Inamen::TokenPattern.parse_query_line(line)
      attrs && !attrs[:disabled]
    end
  end

  def self.valid_search_terms?(edition, query_terms, raw_phrases: nil)
    entries = phrase_entries_for_validation(query_terms, raw_phrases: raw_phrases)
    return false if entries.empty?

    stream = edition.word_stream_index
    return entries.any? unless stream

    entries.any? do |entry|
      completer = Inamen::PhraseCompleter.from_word_stream(stream, case_sensitive: entry.case_sensitive)
      completer.can_search?(entry.phrase)
    end
  end

  def self.phrase_entries_for_validation(query_terms, raw_phrases: nil)
    entries =
      if raw_phrases.present?
        phrase_entries_from_params(raw_phrases)
      else
        phrase_entries_from_query_terms(query_terms)
      end

    entries.reject(&:disabled).select { |entry| entry.phrase.to_s.strip.present? }
  end

  def self.phrase_hashes(raw_phrases)
    return [] if raw_phrases.blank?

    list =
      if raw_phrases.is_a?(ActionController::Parameters)
        raw_phrases.permit!.to_h.values
      elsif raw_phrases.is_a?(Hash)
        raw_phrases.sort_by { |key, _| key.to_i }.map(&:last)
      else
        Array(raw_phrases)
      end

    list.compact.map do |entry|
      hash = entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry.to_h
      hash.symbolize_keys
    end
  end
  private_class_method :phrase_hashes

  def self.run(edition, params, force: false)
    p = params.is_a?(Params) ? params : normalize(params)
    return run_counts(edition, p, force: force) if p.mode == "word_count"
    return compute_file_stats(edition) if p.mode == "file_stats"

    key = cache_key_for(edition, p)
    Rails.cache.delete(key) if force

    Rails.cache.fetch(key, expires_in: 7.days) do
      compute(edition, p)
    end
  end

  def self.run_file_stats(edition, params, force: false)
    run(edition, params, force: force)
  end

  def self.run_counts(edition, params, force: false)
    p = params.is_a?(Params) ? params : normalize(params)
    return [] if p.mode == "word_count" && !valid_search_terms?(edition, p.query_terms)

    key = counts_cache_key_for(edition, p)
    Rails.cache.delete(key) if force

    Rails.cache.fetch(key, expires_in: 7.days) do
      compute_word_count_rows(edition, p)
    end
  end

  def self.run_verses(edition, params, force: false)
    p = params.is_a?(Params) ? params : normalize(params)
    return nil if p.mode != "word_count" || !valid_search_terms?(edition, p.query_terms)

    key = verses_cache_key_for(edition, p)
    Rails.cache.delete(key) if force

    Rails.cache.fetch(key, expires_in: 7.days) do
      compute_verse_result(edition, p)
    end
  end

  def self.enqueue_verses!(edition, params, force: false)
    p = params.is_a?(Params) ? params : normalize(params)
    return unless p.mode == "word_count" && valid_search_terms?(edition, p.query_terms)
    return if verses_cached?(edition, p) && !force
    return if verses_running?(edition, p)

    DiscoveryVerseScanJob.perform_later(edition.edition_id, job_payload(p), force: force)
  end

  def self.compute(edition, params)
    case params.mode
    when "equal_count"
      compute_equal_count(edition, params)
    when "word_count"
      compute_word_count_rows(edition, params)
    when "file_stats"
      compute_file_stats(edition)
    else
      compute_divisible(edition, params)
    end
  end

  def self.compute_file_stats(edition)
    edition.file_stats
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

  def self.compute_word_count_rows(edition, params)
    return [] unless enabled_search_terms?(params.query_terms)

    if params.from_feature == "fishermen_gospels"
      return compute_fishermen_word_count_rows(edition, params)
    end

    terms = word_count_terms(params)

    rows = Inamen::TokenQuery.scan(
      edition.db,
      terms: terms,
      search_selection: params.search_selection,
      word_stream: edition.word_stream_index
    ).map do |row|
      WordCountRow.new(
        pattern: row.pattern,
        case_sensitive: row.case_sensitive,
        count: row.count,
        wildcard: row.wildcard,
        scope: row.scope,
        spellings: row.spellings,
        exclude: row.exclude
      )
    end

    return rows if params.from_feature.blank?

    Inamen::FeatureDiscoverPresets.adjust_rows!(
      params.from_feature,
      edition,
      rows,
      search_selection: params.search_selection,
      query_terms: params.query_terms
    )
  end

  def self.compute_fishermen_word_count_rows(edition, params)
    scope_label = Inamen::FeatureDiscoverPresets.selection_for("fishermen_gospels").label
    stub_rows = phrase_entries_from_query_terms(params.query_terms).reject(&:disabled).reject(&:exclude).map do |entry|
      WordCountRow.new(
        pattern: entry.phrase,
        case_sensitive: entry.case_sensitive,
        count: 0,
        wildcard: entry.phrase.include?("*"),
        scope: scope_label,
        spellings: {},
        exclude: false
      )
    end

    Inamen::FeatureDiscoverPresets.adjust_rows!(
      "fishermen_gospels",
      edition,
      stub_rows,
      search_selection: params.search_selection,
      query_terms: params.query_terms
    )
  end

  def self.compute_verse_result(edition, params)
    verse_result =
      if params.from_feature == "fishermen_gospels"
        exclusions = Inamen::FeatureDiscoverPresets.fishermen_exclusions_from_query_terms(params.query_terms)
        Inamen::FishermenNameCounts.build_verse_result(
          edition.lines,
          scope: :gospels,
          search_selection: params.search_selection,
          james_exclusions: exclusions[:james],
          john_exclusions: exclusions[:john],
          word_stream: edition.word_stream_index,
          edition: edition
        )
      else
        result =
          if params.from_feature == "jesus_mentions" &&
             Inamen::FeatureDiscoverPresets.jesus_antimention_only_query?(params.query_terms)
            Inamen::FeatureDiscoverPresets.build_jesus_antimention_verse_result(
              edition.db,
              search_selection: params.search_selection
            )
          else
            terms = Inamen::TokenQuery.parse_terms(params.query_terms)
            Inamen::VerseMatchQuery.scan(
              edition.db,
              terms: terms,
              search_selection: params.search_selection,
              word_stream: edition.word_stream_index
            )
          end
        if params.from_feature.present?
          result = Inamen::FeatureDiscoverPresets.adjust_verse_result!(params.from_feature, result)
        end
        result
      end
  end

  def self.prepare_verses_for_display!(edition, verse_result, rows: nil)
    return verse_result unless verse_result

    align_verse_summary_with_counts!(verse_result, rows) if rows
    Inamen::VerseMatchQuery.prepare_display!(edition, verse_result)
    verse_result
  end

  def self.word_count_table_total(rows)
    Array(rows).sum do |row|
      next 0 if row.overlap
      row.exclude ? -row.count : row.count
    end
  end

  def self.align_verse_summary_with_counts!(verse_result, rows)
    return verse_result unless verse_result&.summary

    verse_result.summary.occurrences = word_count_table_total(rows)
    verse_result
  end

  def self.word_count_terms(params)
    if params.from_feature == "fishermen_gospels"
      include_only_terms(params.query_terms)
    else
      Inamen::TokenQuery.parse_terms(params.query_terms)
    end
  end

  def self.include_only_terms(query_terms)
    lines = query_terms.to_s.each_line.filter_map do |line|
      attrs = Inamen::TokenPattern.parse_query_line(line)
      next if attrs.nil? || attrs[:disabled] || attrs[:exclude]

      line.strip
    end
    Inamen::TokenQuery.parse_terms(lines.join("\n"))
  end
  private_class_method :include_only_terms

  def self.cached?(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    return counts_cached?(edition, p) if p.mode == "word_count"

    key = cache_key_for(edition, p)
    return false unless Rails.cache.exist?(key)

    !Rails.cache.read(key).nil?
  rescue TypeError
    Rails.cache.delete(key)
    false
  end

  def self.counts_cached?(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    return false if p.mode == "word_count" && !enabled_search_terms?(p.query_terms)

    key = counts_cache_key_for(edition, p)
    return false unless Rails.cache.exist?(key)

    !Rails.cache.read(key).nil?
  rescue TypeError
    Rails.cache.delete(key)
    false
  end

  def self.verses_cached?(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    return false if p.mode != "word_count" || !enabled_search_terms?(p.query_terms)

    key = verses_cache_key_for(edition, p)
    return false unless Rails.cache.exist?(key)

    !Rails.cache.read(key).nil?
  rescue TypeError
    Rails.cache.delete(key)
    false
  end

  def self.read_cached(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    return read_counts_cached(edition, p) if p.mode == "word_count"
    return compute_file_stats(edition) if p.mode == "file_stats"

    cached = Rails.cache.read(cache_key_for(edition, p))
    return cached if cached

    nil
  rescue TypeError
    clear_cache!(edition, p)
    nil
  end

  def self.read_counts_cached(edition, params)
    Rails.cache.read(counts_cache_key_for(edition, params))
  rescue TypeError
    clear_counts_cache!(edition, params)
    nil
  end

  def self.read_verses_cached(edition, params)
    Rails.cache.read(verses_cache_key_for(edition, params))
  rescue TypeError
    clear_verses_cache!(edition, params)
    nil
  end

  def self.clear_cache!(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    if p.mode == "word_count"
      clear_counts_cache!(edition, p)
      clear_verses_cache!(edition, p)
    else
      Rails.cache.delete(cache_key_for(edition, p))
    end
  end

  def self.clear_counts_cache!(edition, params)
    Rails.cache.delete(counts_cache_key_for(edition, params))
  end

  def self.clear_verses_cache!(edition, params)
    Rails.cache.delete(verses_cache_key_for(edition, params))
  end

  def self.running?(edition, params)
    Rails.cache.exist?(running_key_for(edition, params))
  end

  def self.verses_running?(edition, params)
    Rails.cache.exist?(verses_running_key_for(edition, params))
  end

  def self.running_key_for(edition, params)
    "#{cache_key_for(edition, params)}/running"
  end

  def self.verses_running_key_for(edition, params)
    "#{verses_cache_key_for(edition, params)}/running"
  end

  def self.job_payload(params)
    p = params.is_a?(Params) ? params : normalize(params)
    payload = {
      mode: p.mode,
      divisible_by: p.divisible_by,
      search_selection: p.search_selection.to_h.merge(submitted: "1"),
      min_count: p.min_count,
      min_group_size: p.min_group_size,
      match_by: p.match_by,
      query_terms: p.query_terms
    }
    payload[:from_feature] = p.from_feature if p.from_feature.present?
    payload
  end

  def self.cache_key_for(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    shared_cache_components(p, edition)
  end

  def self.counts_cache_key_for(edition, params)
    ["discovery_counts/v24", *shared_cache_components(params, edition)]
  end

  def self.verses_cache_key_for(edition, params)
    ["discovery_verses/v25", *shared_cache_components(params, edition)]
  end

  def self.shared_cache_components(params, edition)
    p = params.is_a?(Params) ? params : normalize(params)
    terms_digest =
      if p.mode == "word_count" && p.query_terms.present?
        Digest::SHA256.hexdigest(p.query_terms)[0, 16]
      end
    [
      p.mode,
      p.match_by,
      terms_digest,
      edition.edition_id,
      edition.checksum_prefix,
      Inamen::CorpusStore::INDEXER_REVISION,
      p.divisible_by,
      p.search_selection.cache_key,
      p.min_count,
      p.min_group_size,
      p.from_feature
    ]
  end
end
