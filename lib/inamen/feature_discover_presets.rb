# frozen_string_literal: true

require_relative "book_categories"
require_relative "bible_boundary_patterns"
require_relative "search_selection"
require_relative "corpus_store"
require_relative "verse_match_query"
require_relative "token_query"

module Inamen
  # Maps catalog feature IDs to Discover word-count scan presets.
  module FeatureDiscoverPresets
    Phrase = Struct.new(:phrase, :case_sensitive, :exclude, :disabled, keyword_init: true) do
      def initialize(phrase:, case_sensitive: false, exclude: false, disabled: false)
        super
      end
    end

    Preset = Struct.new(:phrases, :scope, :exclude_verses, :verse_metric, keyword_init: true) do
      def initialize(phrases:, scope:, exclude_verses: nil, verse_metric: nil)
        super
      end
    end

    JESUS_POSSESSIVE = "Jesus\u2019"
    JESUS_PATTERNS = ["Jesus", "JESUS", JESUS_POSSESSIVE].freeze
    JESUS_PHRASE = "Jesus|JESUS|#{JESUS_POSSESSIVE}"

    BIBLE_BOUNDARY_PHRASES = [
      Phrase.new(phrase: "In"),
      Phrase.new(phrase: "earth", case_sensitive: true),
      Phrase.new(phrase: "The"),
      Phrase.new(phrase: "Amen", case_sensitive: true)
    ].freeze

    SCOPES = {
      scannable: -> { SearchSelection.default },
      verse_text: lambda {
        SearchSelection.new(
          colophons: false,
          superscriptions: false,
          books: BookCategories.all_books
        )
      },
      gospels: lambda {
        SearchSelection.new(
          colophons: false,
          superscriptions: false,
          books: BookCategories.books_for_category(:nt, :gospels)
        )
      },
      new_testament: lambda {
        SearchSelection.new(
          colophons: false,
          superscriptions: false,
          books: BookCategories.nt_books
        )
      },
      old_testament: lambda {
        SearchSelection.new(
          colophons: false,
          superscriptions: false,
          books: BookCategories.ot_books
        )
      },
      genesis_revelation: lambda {
        SearchSelection.new(
          colophons: false,
          superscriptions: false,
          books: BibleBoundaryPatterns::GEN_REV
        )
      },
      first_7_nt: lambda {
        SearchSelection.new(
          colophons: false,
          superscriptions: false,
          books: BibleBoundaryPatterns::FIRST_7_NT
        )
      }
    }.freeze

    GOD_PURE_PHRASE = "God|God\u2019s|Gods|Godhead|God-ward"

    PRESETS = {
      "amen_77" => Preset.new(
        phrases: [Phrase.new(phrase: "Amen", case_sensitive: true)],
        scope: :scannable
      ),
      "bible_boundary_words" => Preset.new(
        phrases: BIBLE_BOUNDARY_PHRASES,
        scope: :scannable
      ),
      "boundary_anchor_verses" => Preset.new(
        phrases: BIBLE_BOUNDARY_PHRASES,
        scope: :scannable
      ),
      "boundary_seven_forms" => Preset.new(
        phrases: [
          Phrase.new(phrase: "In|IN", case_sensitive: true),
          Phrase.new(phrase: "in", case_sensitive: true),
          Phrase.new(phrase: "earth", case_sensitive: true),
          Phrase.new(phrase: "The", case_sensitive: true),
          Phrase.new(phrase: "the", case_sensitive: true),
          Phrase.new(phrase: "THE", case_sensitive: true),
          Phrase.new(phrase: "Amen", case_sensitive: true)
        ],
        scope: :scannable
      ),
      "beginning_end_amen" => Preset.new(
        phrases: [
          Phrase.new(phrase: "beginning"),
          Phrase.new(phrase: "end"),
          Phrase.new(phrase: "Amen", case_sensitive: true)
        ],
        scope: :scannable
      ),
      "in_amen_genesis_revelation" => Preset.new(
        phrases: [
          Phrase.new(phrase: "in"),
          Phrase.new(phrase: "Amen", case_sensitive: true)
        ],
        scope: :genesis_revelation
      ),
      "god_jesus_genesis_revelation" => Preset.new(
        phrases: [
          Phrase.new(phrase: "God"),
          Phrase.new(phrase: "Jesus|JESUS", case_sensitive: true)
        ],
        scope: :genesis_revelation
      ),
      "the_amen_nt_concealed" => Preset.new(
        phrases: [
          Phrase.new(phrase: "The*|THE*", case_sensitive: true),
          Phrase.new(phrase: "Amen*|AMEN*", case_sensitive: true)
        ],
        scope: :new_testament
      ),
      "god_pure_nt" => Preset.new(
        phrases: [Phrase.new(phrase: GOD_PURE_PHRASE, case_sensitive: true)],
        scope: :new_testament
      ),
      "jesus_mentions" => Preset.new(
        phrases: [
          Phrase.new(phrase: JESUS_PHRASE, case_sensitive: true),
          Phrase.new(phrase: JesusMentionsAntimentions.exclude_phrase, exclude: true, case_sensitive: true)
        ],
        scope: :scannable
      ),
      "jesus_boundary_same_verse" => Preset.new(
        phrases: BIBLE_BOUNDARY_PHRASES + [Phrase.new(phrase: JESUS_PHRASE, case_sensitive: true)],
        scope: :scannable,
        exclude_verses: BibleBoundaryPatterns::JESUS_NON_CHRIST_VERSES
      ),
      "peter_verses" => Preset.new(
        phrases: [Phrase.new(phrase: "Peter")],
        scope: :scannable,
        verse_metric: :verse_text
      ),
      "paul_verses" => Preset.new(
        phrases: [Phrase.new(phrase: "Paul")],
        scope: :scannable,
        verse_metric: :verse_text
      ),
      "fishermen_gospels" => Preset.new(
        phrases: [
          Phrase.new(phrase: "Peter*"),
          Phrase.new(phrase: "Thomas*"),
          Phrase.new(phrase: "Nathanael*"),
          Phrase.new(phrase: "James*"),
          Phrase.new(phrase: "John*"),
          Phrase.new(phrase: FishermenGospelsKjs.james_exclude_phrase, exclude: true),
          Phrase.new(phrase: FishermenGospelsKjs.john_exclude_phrase, exclude: true)
        ],
        scope: :gospels
      )
    }.freeze

    class << self
      FILE_STATS_FEATURES = %w[combined_total file_character_total].freeze
      # Presets whose exclude rows are loaded from bundled KJS/data files — keep out of session URLs.
      BULKY_PHRASE_FEATURES = %w[fishermen_gospels jesus_mentions].freeze

      def discoverable?(feature_id)
        PRESETS.key?(feature_id.to_s) || FILE_STATS_FEATURES.include?(feature_id.to_s)
      end

      def discover_mode_for(feature_id)
        return "file_stats" if FILE_STATS_FEATURES.include?(feature_id.to_s)

        "word_count"
      end

      def discover_highlight_for(feature_id)
        case feature_id.to_s
        when "file_character_total" then "file_characters"
        when "combined_total" then "combined_total"
        end
      end

      def preset_for(feature_id)
        PRESETS[feature_id.to_s]
      end

      def search_selection_for(scope)
        builder = SCOPES.fetch(scope) { raise ArgumentError, "Unknown scope: #{scope.inspect}" }
        builder.call
      end

      def phrase_entries_for(feature_id)
        preset = preset_for(feature_id)
        return [] unless preset

        preset.phrases.map { |phrase| phrase_entry_hash(phrase) }
      end

      def phrase_entries_for_link(feature_id)
        phrase_entries_for(feature_id).reject { |entry| entry[:exclude] }
      end

      def bulky_phrase_feature?(feature_id)
        BULKY_PHRASE_FEATURES.include?(feature_id.to_s)
      end

      FISHERMEN_INCLUDE_PHRASES = %w[Peter* Thomas* Nathanael* James* John*].freeze

      def fishermen_preset_includes?(raw)
        phrases = include_phrases_from_raw(raw)
        FISHERMEN_INCLUDE_PHRASES.all? { |pattern| phrases.include?(pattern) }
      end

      def jesus_preset_includes?(raw)
        include_phrases_from_raw(raw).include?(JESUS_PHRASE)
      end

      def bulky_preset_includes?(feature_id, raw)
        case feature_id.to_s
        when "fishermen_gospels" then fishermen_preset_includes?(raw)
        when "jesus_mentions" then jesus_preset_includes?(raw)
        else false
        end
      end

      def fishermen_query_simplified?(raw)
        return false if raw.nil? || raw.empty?

        include_phrases_from_raw(raw).sort != FISHERMEN_INCLUDE_PHRASES.sort
      end

      def jesus_query_simplified?(raw)
        return false if raw.nil? || raw.empty?

        include_phrases_from_raw(raw) != [JESUS_PHRASE]
      end

      def bulky_query_simplified?(feature_id, raw)
        case feature_id.to_s
        when "fishermen_gospels" then fishermen_query_simplified?(raw)
        when "jesus_mentions" then jesus_query_simplified?(raw)
        else false
        end
      end

      def include_phrases_from_raw(raw)
        normalize_raw_phrases_hash(raw).values.filter_map do |row|
          next if boolean_param(row["exclude"])
          next if boolean_param(row["disabled"])

          phrase = row["phrase"].to_s.strip
          phrase unless phrase.empty?
        end
      end

      def search_phrases_hash_for(feature_id, raw: nil, merge_preset_excludes: true)
        return raw if feature_id.to_s.empty? || !bulky_phrase_feature?(feature_id)

        preset = preset_search_phrases_hash(feature_id)
        return preset if raw.nil? || raw.empty?

        normalized = normalize_raw_phrases_hash(raw)
        return normalized if raw_has_exclude_phrases?(raw)
        return normalized if bulky_query_simplified?(feature_id, normalized)
        return normalized unless merge_preset_excludes

        merged = preset.dup
        raw.each do |idx, row|
          next if boolean_param(row["exclude"] || row[:exclude])

          merged[idx.to_s] = stringify_phrase_row(row)
        end
        merged
      end

      def resolve_from_feature(feature_id, query_terms:)
        inferred = infer_bulk_feature_from_query(query_terms)

        id = feature_id.to_s
        id = nil if id.empty?

        if inferred == "jesus_mentions" && jesus_mentions_query?(query_terms)
          return "jesus_mentions"
        end
        if inferred == "fishermen_gospels" && fishermen_gospels_query?(query_terms)
          return "fishermen_gospels"
        end

        id = inferred if id.nil?
        return nil unless id

        case id
        when "fishermen_gospels"
          fishermen_gospels_query?(query_terms) ? id : nil
        when "jesus_mentions"
          jesus_mentions_query?(query_terms) ? id : nil
        else
          preset_for(id) ? id : nil
        end
      end

      def infer_bulk_feature_from_query(query_terms)
        return "fishermen_gospels" if fishermen_gospels_query?(query_terms)
        return "jesus_mentions" if jesus_mentions_query?(query_terms)

        nil
      end

      def jesus_mentions_query?(query_terms)
        jesus_antimentions_in_query?(query_terms) || jesus_include_phrase_in_query?(query_terms)
      end

      def jesus_include_phrase_in_query?(query_terms)
        query_terms.to_s.each_line.any? do |line|
          attrs = TokenPattern.parse_query_line(line)
          next unless attrs && !attrs[:exclude] && !attrs[:disabled]

          jesus_include_pattern?(attrs[:pattern])
        end
      end

      def jesus_include_pattern?(pattern)
        return true if pattern.to_s == JESUS_PHRASE

        alts = split_include_alternatives(pattern)
        jesus_alts = split_include_alternatives(JESUS_PHRASE)
        alts.any? && (alts - jesus_alts).empty?
      end

      def jesus_antimentions_in_query?(query_terms)
        query_terms.to_s.each_line.any? do |line|
          attrs = TokenPattern.parse_query_line(line)
          next false unless attrs && !attrs[:disabled]

          jesus_antimention_phrase?(attrs[:pattern]) || jesus_antimention_part?(attrs[:pattern])
        end
      end

      def jesus_antimention_phrase?(pattern)
        pattern.to_s.match?(/\AANTIMENTIONS OF JESUS/i)
      end

      def jesus_antimention_part?(pattern)
        normalized = pattern.to_s.strip
        JesusMentionsAntimentions::ANTIMENTION_PARTS.any? do |part|
          normalized == part || normalized.start_with?(part)
        end
      end

      def fishermen_gospels_query?(query_terms)
        fishermen_antimentions_in_query?(query_terms) ||
          fishermen_all_preset_includes_in_query?(query_terms) ||
          query_terms.to_s.each_line.any? do |line|
            attrs = TokenPattern.parse_query_line(line)
            next unless attrs && !attrs[:exclude] && !attrs[:disabled]

            fishermen_name_pattern?(attrs[:pattern])
          end
      end

      def fishermen_all_preset_includes_in_query?(query_terms)
        phrases = query_terms.to_s.each_line.filter_map do |line|
          attrs = TokenPattern.parse_query_line(line)
          next if !attrs || attrs[:exclude] || attrs[:disabled]

          attrs[:pattern]
        end
        FISHERMEN_INCLUDE_PHRASES.all? { |pattern| phrases.include?(pattern) }
      end

      def fishermen_antimentions_in_query?(query_terms)
        query_terms.to_s.each_line.any? do |line|
          attrs = TokenPattern.parse_query_line(line)
          next false unless attrs && !attrs[:disabled]

          fishermen_antimention_phrase?(attrs[:pattern])
        end
      end

      def bulky_antimention_phrase?(pattern)
        fishermen_antimention_phrase?(pattern) || jesus_antimention_phrase?(pattern)
      end

      def fishermen_antimention_phrase?(pattern)
        pattern.to_s.match?(/\AANTIMENTIONS OF (JAMES|JOHN)/i)
      end

      def fishermen_name_pattern?(pattern)
        split_include_alternatives(pattern).any? do |alternative|
          alternative.match?(/\AJames\*/i) || alternative.match?(/\AJohn\*/i)
        end
      end

      def bulky_phrases_customized?(feature_id, phrases)
        case feature_id.to_s
        when "fishermen_gospels" then fishermen_phrases_customized?(feature_id, phrases)
        when "jesus_mentions" then jesus_phrases_customized?(phrases)
        else false
        end
      end

      def jesus_phrases_customized?(phrases)
        return false if phrases.nil? || phrases.empty?
        return false unless raw_has_exclude_phrases?(phrases)

        normalized = normalize_raw_phrases_hash(phrases)
        return true if normalized.values.any? { |row| boolean_param(row["disabled"]) }

        preset = preset_search_phrases_hash("jesus_mentions")
        extract_exclude_phrases(phrases) != extract_exclude_phrases(preset)
      end

      def fishermen_phrases_customized?(feature_id, phrases)
        return false unless feature_id.to_s == "fishermen_gospels"
        return false if phrases.nil? || phrases.empty?
        return false unless raw_has_exclude_phrases?(phrases)

        normalized = normalize_raw_phrases_hash(phrases)
        return true if normalized.values.any? { |row| boolean_param(row["disabled"]) }

        preset = preset_search_phrases_hash(feature_id)
        extract_exclude_phrases(phrases) != extract_exclude_phrases(preset)
      end

      def raw_has_exclude_phrases?(raw)
        raw.any? { |_, row| boolean_param(row["exclude"] || row[:exclude]) }
      end

      def normalize_raw_phrases_hash(raw)
        raw.sort_by { |key, _| key.to_i }.each_with_object({}) do |(idx, row), hash|
          hash[idx.to_s] = stringify_phrase_row(row)
        end
      end

      def search_phrases_from_post(feature_id, raw_post)
        normalized = normalize_raw_phrases_hash(raw_post)
        simplified = bulky_query_simplified?(feature_id, normalized)
        hydrated = search_phrases_hash_for(
          feature_id,
          raw: normalized,
          merge_preset_excludes: !simplified && bulky_preset_includes?(feature_id, normalized)
        )

        unless simplified
          if bulky_preset_includes?(feature_id, normalized) || raw_has_exclude_phrases?(normalized)
            preset = preset_search_phrases_hash(feature_id)
            preset.each do |idx, row|
              next unless boolean_param(row["exclude"])
              next if hydrated.key?(idx.to_s)

              hydrated[idx.to_s] = stringify_phrase_row(row)
            end
          end
        end

        normalized.each do |idx, posted|
          key = idx.to_s
          if hydrated[key]
            hydrated[key] = overlay_posted_phrase_row(hydrated[key], posted)
          else
            overlay_posted_exclude_row!(hydrated, posted)
          end
        end

        normalize_raw_phrases_hash(hydrated)
      end

      def overlay_posted_phrase_row(stored, posted)
        row = stringify_phrase_row(stored)
        posted = posted.transform_keys(&:to_s)
        row["phrase"] = posted["phrase"] if posted["phrase"].to_s != ""
        full_row_post = posted.key?("phrase")
        %w[case_sensitive exclude disabled].each do |flag|
          if posted.key?(flag)
            if boolean_param(posted[flag])
              row[flag] = "1"
            else
              row.delete(flag)
            end
          elsif full_row_post
            row.delete(flag)
          end
        end
        row
      end

      def overlay_posted_exclude_row!(hydrated, posted)
        return unless boolean_param(posted["exclude"] || posted[:exclude]) ||
                      boolean_param(posted["disabled"] || posted[:disabled])

        header = posted[:phrase] || posted["phrase"]
        header = header.to_s.split("|").first&.strip
        return if header.nil? || header.empty?

        hydrated.each do |_, row|
          next unless row["phrase"].to_s.start_with?(header)

          overlay_posted_phrase_row(row, posted).each do |key, value|
            row[key] = value
          end
        end
      end

      def fishermen_exclusions_from_query_terms(query_terms)
        entries = fishermen_phrase_entries_from_query_terms(query_terms)
        exclude_rows = entries.select { |entry| entry[:exclude] }
        use_defaults = exclude_rows.empty?

        {
          james: fishermen_exclusion_parts_for(exclude_rows, :james, use_defaults),
          john: fishermen_exclusion_parts_for(exclude_rows, :john, use_defaults)
        }
      end

      def fishermen_exclusion_parts_for(exclude_rows, which, use_defaults)
        label = which == :james ? "ANTIMENTIONS OF JAMES" : "ANTIMENTIONS OF JOHN"
        default = which == :james ? FishermenGospelsKjs.james_exclusions : FishermenGospelsKjs.john_exclusions
        row = exclude_rows.find { |entry| entry[:phrase].start_with?(label) }
        return default if row.nil? && use_defaults
        return [] if row.nil? || row[:disabled]

        FishermenGospelsKjs.antimention_parts(row[:phrase])
      end

      def compact_search_phrases_for_session(feature_id, phrases)
        return phrases if feature_id.to_s.empty? || !bulky_phrase_feature?(feature_id) || phrases.nil? || phrases.empty?
        return normalize_raw_phrases_hash(phrases) if bulky_phrases_customized?(feature_id, phrases)
        return normalize_raw_phrases_hash(phrases) if bulky_query_simplified?(feature_id, phrases)

        phrases.each_with_object({}) do |(idx, row), compact|
          next if boolean_param(row["exclude"] || row[:exclude])

          compact[idx.to_s] = stringify_phrase_row(row)
        end
      end

      def compact_discover_query_for_session(feature_id, query)
        return query unless bulky_phrase_feature?(feature_id)

        compact = query.to_h.transform_keys(&:to_sym)
        compact.delete(:query_terms)
        if bulky_phrases_customized?(feature_id, compact[:search_phrases])
          compact[:search_phrases] = normalize_raw_phrases_hash(compact[:search_phrases])
        else
          compact[:search_phrases] = compact_search_phrases_for_session(feature_id, compact[:search_phrases])
        end
        compact.compact
      end

      def omit_query_terms_from_urls?(feature_id)
        bulky_phrase_feature?(feature_id)
      end

      def selection_for(feature_id)
        preset = preset_for(feature_id)
        return SearchSelection.default unless preset

        search_selection_for(preset.scope)
      end

      def selection_query_for(feature_id)
        selection_to_query(selection_for(feature_id))
      end

      def selection_to_query(selection)
        query = {
          submitted: "1",
          colophons: selection.colophons ? "1" : "0",
          superscriptions: selection.superscriptions ? "1" : "0"
        }
        if selection.books.sort == BookCategories.all_books.sort
          query[:all_books] = "1"
        else
          query[:books] = selection.books
        end
        query
      end

      def adjust_rows!(feature_id, edition, rows, search_selection:, query_terms:)
        preset = preset_for(feature_id)
        return rows unless preset

        if feature_id.to_s == "fishermen_gospels"
          return adjust_fishermen_rows!(edition, rows, query_terms: query_terms)
        end

        if feature_id.to_s == "jesus_mentions"
          return adjust_jesus_rows!(edition, rows, query_terms: query_terms, search_selection: search_selection)
        end

        if preset.exclude_verses&.any?
          subtract = tokens_in_verses(
            edition.db,
            search_selection,
            verses: preset.exclude_verses,
            token_raws: JESUS_PATTERNS
          )
          jesus_patterns = JESUS_PHRASE.split("|")
          apply_subtraction!(rows, subtract, only_patterns: jesus_patterns)
        end

        rows
      end

      def adjust_verse_result!(feature_id, verse_result)
        preset = preset_for(feature_id)
        return verse_result unless preset&.verse_metric == :verse_text

        text_rows = verse_result.verses.select { |row| row.bucket == CorpusStore::BUCKET_VERSE_TEXT }
        verse_result.verses = text_rows
        verse_result.summary.verses = text_rows.length
        verse_result.summary.books = text_rows.map(&:book).uniq.length
        verse_result.summary.chapters = text_rows.map { |row| [row.book, row.chapter] }.uniq.length
        verse_result
      end

      def jesus_antimention_only_query?(query_terms)
        entries = fishermen_phrase_entries_from_query_terms(query_terms).reject { |entry| entry[:disabled] }
        jesus_antimention_rows_active?(entries) && !jesus_include_rows_active?(entries)
      end

      def build_jesus_antimention_verse_result(db, search_selection:)
        require_relative "verse_match_query"
        require_relative "canon_index"

        selection = search_selection.is_a?(SearchSelection) ? search_selection : SearchSelection.default
        where_sql, where_params = selection.where_clause
        token_placeholders = (["?"] * JESUS_PATTERNS.length).join(", ")
        merged = {}

        JesusMentionsAntimentions::EXCLUDE_VERSES.each do |book, chapter, verse|
          sql = <<~SQL
            SELECT word_index FROM tokens
            WHERE book = ? AND chapter = ? AND verse = ?
              AND token_raw IN (#{token_placeholders})
              #{where_sql}
            ORDER BY word_index
          SQL
          params = [book, chapter, verse, *JESUS_PATTERNS, *where_params]
          indices = db.execute(sql, params).map { |row| row[0].to_i }
          next if indices.empty?

          merged[[book, chapter, verse, CorpusStore::BUCKET_VERSE_TEXT]] = indices
        end

        verses = merged.map do |(book, chapter, verse, bucket), indices|
          sorted = indices.sort.uniq
          VerseMatchQuery::VerseRow.new(
            book: book,
            chapter: chapter,
            verse: verse,
            bucket: bucket,
            occurrence_count: indices.length,
            highlight_indices: sorted,
            first_hit_index: nil
          )
        end
        verses.sort_by! { |row| CanonIndex.sort_key(row.book, row.chapter, row.verse) + [row.bucket] }
        verses.each_with_index { |row, index| row.first_hit_index = index + 1 }

        VerseMatchQuery::Result.new(
          summary: VerseMatchQuery::Summary.new(
            occurrences: verses.sum(&:occurrence_count),
            verses: verses.length,
            chapters: verses.map { |row| [row.book, row.chapter] }.uniq.length,
            books: verses.map(&:book).uniq.length,
            scope_label: selection.label
          ),
          verses: verses,
          hits: []
        )
      end

      private

      def phrase_entry_hash(phrase)
        {
          phrase: phrase.phrase,
          case_sensitive: phrase.case_sensitive,
          exclude: phrase.exclude,
          disabled: phrase.disabled
        }
      end

      def preset_search_phrases_hash(feature_id)
        phrase_entries_for(feature_id).each_with_index.to_h do |phrase, index|
          [index.to_s, stringify_phrase_row(phrase)]
        end
      end

      def stringify_phrase_row(row)
        out = { "phrase" => row[:phrase] || row["phrase"] }
        out["case_sensitive"] = "1" if boolean_param(row[:case_sensitive] || row["case_sensitive"])
        out["exclude"] = "1" if boolean_param(row[:exclude] || row["exclude"])
        out["disabled"] = "1" if boolean_param(row[:disabled] || row["disabled"])
        out
      end

      def boolean_param(value)
        value == true || value == 1 || value.to_s == "1" || value.to_s.casecmp("true").zero?
      end

      def adjust_fishermen_rows!(edition, rows, query_terms:)
        entries = fishermen_phrase_entries_from_query_terms(query_terms).reject { |entry| entry[:disabled] }
        exclusions = fishermen_exclusions_from_query_terms(query_terms)
        bundle = FishermenNameCounts.gospel_scan_bundle(
          edition.lines,
          james_exclusions: exclusions[:james],
          john_exclusions: exclusions[:john],
          edition: edition,
          search_selection: FeatureDiscoverPresets.selection_for("fishermen_gospels")
        )
        gross = bundle.gross
        gross_spellings = bundle.gross_spellings
        net = bundle.net
        gross_by_pattern = {
          "Peter*" => gross[:peter],
          "Thomas*" => gross[:thomas],
          "Nathanael*" => gross[:nathanael],
          "James*" => gross[:james],
          "John*" => gross[:john]
        }
        spellings_by_pattern = {
          "Peter*" => gross_spellings[:peter],
          "Thomas*" => gross_spellings[:thomas],
          "Nathanael*" => gross_spellings[:nathanael],
          "James*" => gross_spellings[:james],
          "John*" => gross_spellings[:john]
        }
        include_rows = rows.reject(&:exclude).each_with_object({}) { |row, index| index[row.pattern] = row }
        scope_label = include_rows.values.first&.scope || selection_for("fishermen_gospels").label
        row_class = rows.first&.class || Inamen::TokenQuery::ResultRow

        entries.map do |entry|
          pattern = entry[:phrase]
          source = fishermen_include_source(pattern, include_rows)
          antimention = bulky_antimention_phrase?(pattern)
          count =
            if entry[:exclude] || antimention
              key = fishermen_exclude_key(pattern)
              gross[key] - net[key]
            else
              fishermen_include_count(pattern, gross_by_pattern, include_rows)
            end
          row_class.new(
            pattern: pattern,
            case_sensitive: entry[:case_sensitive],
            count: count,
            wildcard: source&.wildcard || pattern.include?("*"),
            scope: scope_label,
            spellings: fishermen_row_spellings(
              entry,
              include_rows: include_rows,
              spellings_by_pattern: spellings_by_pattern,
              antimention: antimention
            ),
            exclude: entry[:exclude]
          )
        end
      end

      def fishermen_include_count(pattern, gross_by_pattern, include_rows)
        split_include_alternatives(pattern).sum do |alternative|
          gross_by_pattern.fetch(alternative) { include_rows[alternative]&.count || 0 }
        end
      end

      def fishermen_include_source(pattern, include_rows)
        split_include_alternatives(pattern).filter_map { |alternative| include_rows[alternative] }.first
      end

      def split_include_alternatives(pattern)
        TokenPattern.split_phrase_patterns(pattern)
      rescue ArgumentError
        pattern.to_s.split("|").map(&:strip).reject(&:empty?)
      end

      def fishermen_phrase_entries_from_query_terms(query_terms)
        query_terms.to_s.each_line.filter_map do |line|
          attrs = TokenPattern.parse_query_line(line)
          next unless attrs

          phrase_entry_hash(
            Phrase.new(
              phrase: attrs[:pattern],
              case_sensitive: attrs[:case_sensitive],
              exclude: attrs[:exclude],
              disabled: attrs[:disabled]
            )
          )
        end
      end

      def fishermen_exclude_key(pattern)
        pattern.match?(/JAMES/i) ? :james : :john
      end

      def extract_exclude_phrases(phrases)
        normalize_raw_phrases_hash(phrases).sort_by { |key, _| key.to_i }.filter_map do |_, row|
          next unless boolean_param(row["exclude"])

          row["phrase"]
        end
      end

      def fishermen_row_spellings(entry, include_rows:, spellings_by_pattern:, antimention: false)
        return {} if entry[:exclude] || antimention

        alternatives = split_include_alternatives(entry[:phrase])
        merged = alternatives.each_with_object({}) do |alternative, hash|
          spellings = spellings_by_pattern[alternative]
          if spellings.nil? || spellings.empty?
            row = include_rows[alternative]
            spellings = row&.spellings || {}
          end

          spellings.each do |raw, count|
            hash[raw] = hash.fetch(raw, 0) + count
          end
        end

        merged.sort_by { |raw, count| [-count, raw] }.to_h
      end

      def adjust_jesus_rows!(edition, rows, query_terms:, search_selection:)
        all_entries = fishermen_phrase_entries_from_query_terms(query_terms)
        entries = all_entries.reject { |entry| entry[:disabled] }
        exclude_amount = jesus_exclude_amount(edition.db, search_selection, entries)
        include_rows = rows.reject(&:exclude).each_with_object({}) { |row, index| index[row.pattern] = row }
        scope_label = selection_for("jesus_mentions").label
        row_class = rows.first&.class || Inamen::TokenQuery::ResultRow

        if entries.one? && !entries.first[:exclude] && !jesus_antimention_rows_active?(entries)
          if jesus_apply_default_subtraction?(all_entries)
            subtract = tokens_in_verses(
              edition.db,
              search_selection,
              verses: JesusMentionsAntimentions::EXCLUDE_VERSES,
              token_raws: JESUS_PATTERNS
            )
            apply_subtraction!(rows, subtract)
          end
          return rows
        end

        entries.map do |entry|
          pattern = entry[:phrase]
          stripped = pattern.to_s.strip
          source = include_rows[stripped] || include_rows[pattern] || include_rows[JESUS_PHRASE]
          antimention = jesus_antimention_phrase?(stripped) || jesus_antimention_part?(stripped)
          count =
            if entry[:exclude]
              jesus_exclude_row_count(stripped, include_rows, exclude_amount)
            elsif antimention
              exclude_amount
            elsif jesus_include_pattern?(stripped)
              jesus_gross_token_count(edition.db, search_selection)
            else
              source&.count || 0
            end
          overlap = antimention && jesus_include_rows_active?(entries) && !entry[:exclude]
          row_class.new(
            pattern: pattern,
            case_sensitive: entry[:case_sensitive],
            count: count,
            wildcard: source&.wildcard || pattern.include?("*"),
            scope: scope_label,
            spellings: jesus_row_spellings(entry, antimention:, include_rows:, source:, pattern: stripped),
            exclude: entry[:exclude],
            overlap: overlap
          )
        end
      end

      def jesus_exclude_row_count(pattern, include_rows, exclude_amount)
        if jesus_antimention_phrase?(pattern)
          exclude_amount
        elsif jesus_antimention_part?(pattern)
          include_rows[pattern]&.count || 1
        else
          include_rows[pattern]&.count || 0
        end
      end

      def jesus_row_spellings(entry, antimention:, include_rows:, source:, pattern:)
        return {} if entry[:exclude] || antimention
        return jesus_include_spellings(include_rows) if jesus_include_pattern?(pattern)

        source&.spellings || {}
      end

      def jesus_include_spellings(include_rows)
        split_include_alternatives(JESUS_PHRASE).each_with_object({}) do |alternative, hash|
          spellings = include_rows[alternative]&.spellings || {}
          spellings.each do |raw, count|
            hash[raw] = hash.fetch(raw, 0) + count
          end
        end.sort_by { |raw, count| [-count, raw] }.to_h
      end

      def jesus_gross_token_count(db, search_selection)
        where_sql, where_params = search_selection.where_clause
        token_placeholders = (["?"] * JESUS_PATTERNS.length).join(", ")
        sql = <<~SQL
          SELECT COUNT(*) FROM tokens
          WHERE token_raw IN (#{token_placeholders})
          #{where_sql}
        SQL
        db.execute(sql, [*JESUS_PATTERNS, *where_params]).first.first.to_i
      end

      def jesus_exclude_amount(db, search_selection, entries)
        return 0 unless jesus_antimention_rows_active?(entries)

        tokens_in_verses(
          db,
          search_selection,
          verses: JesusMentionsAntimentions::EXCLUDE_VERSES,
          token_raws: JESUS_PATTERNS
        )
      end

      def jesus_antimention_rows_active?(entries)
        entries.any? do |entry|
          next false if entry[:disabled]

          jesus_antimention_phrase?(entry[:phrase]) || jesus_antimention_part?(entry[:phrase])
        end
      end

      def jesus_apply_default_subtraction?(all_entries)
        !all_entries.any? do |entry|
          jesus_antimention_phrase?(entry[:phrase]) || jesus_antimention_part?(entry[:phrase])
        end
      end

      def jesus_include_rows_active?(entries)
        entries.any? do |entry|
          next false if entry[:exclude]
          next false if jesus_antimention_phrase?(entry[:phrase])
          next false if jesus_antimention_part?(entry[:phrase])

          entry[:phrase].to_s.strip != ""
        end
      end

      def tokens_in_verses(db, selection, verses:, token_raws:)
        where_sql, where_params = selection.where_clause
        token_placeholders = (["?"] * token_raws.length).join(", ")

        verses.sum do |book, chapter, verse|
          sql = <<~SQL
            SELECT COUNT(*) FROM tokens
            WHERE book = ? AND chapter = ? AND verse = ?
              AND token_raw IN (#{token_placeholders})
              #{where_sql}
          SQL
          params = [book, chapter, verse, *token_raws, *where_params]
          db.execute(sql, params).first.first.to_i
        end
      end

      def apply_subtraction!(rows, amount, only_patterns: nil)
        return if amount <= 0

        remaining = amount
        rows.each do |row|
          next if row.exclude
          next if only_patterns && !only_patterns.include?(row.pattern)

          break if remaining <= 0

          take = [row.count, remaining].min
          row.count -= take
          remaining -= take
        end
      end
    end
  end
end
