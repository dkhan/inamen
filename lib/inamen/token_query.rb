# frozen_string_literal: true

module Inamen
  # Count token occurrences for one or more search patterns (exact or * wildcard).
  module TokenQuery
    QueryTerm = Struct.new(:pattern, :case_sensitive, :exclude, keyword_init: true)
    ResultRow = Struct.new(:pattern, :case_sensitive, :count, :wildcard, :scope, :spellings, :exclude, :overlap,
                           keyword_init: true)

    MAX_TERMS = 100

    class << self
      def parse_terms(text)
        terms = text.to_s.each_line.flat_map do |line|
          attrs = TokenPattern.parse_query_line(line)
          next [] unless attrs
          next [] if attrs[:disabled]

          patterns =
            if attrs[:exclude] && bulk_antimention_exclude?(attrs[:pattern])
              [attrs[:pattern]]
            else
              TokenPattern.split_phrase_patterns(attrs[:pattern])
            end

          patterns.map do |pattern|
            QueryTerm.new(
              pattern: pattern,
              case_sensitive: attrs[:case_sensitive],
              exclude: attrs[:exclude]
            )
          end
        end
        raise ArgumentError, "at least one search term required" if terms.empty?
        raise ArgumentError, "too many terms (max #{MAX_TERMS})" if terms.length > MAX_TERMS

        terms
      end

      def scan(db, terms:, search_selection: nil, scope: :whole_bible, bucket: :default, word_stream: nil)
        selection = resolve_selection(search_selection, scope, bucket)
        scope_label = TokenCountQuery.selection_label(selection)
        if word_stream
          return scan_with_word_stream(word_stream, terms, selection, scope_label)
        end

        Array(terms).map do |term|
          count, spellings =
            if PhraseQuery.phrase?(term.pattern)
              PhraseQuery.count(
                db,
                pattern: term.pattern,
                search_selection: selection,
                case_sensitive: term.case_sensitive
              )
            elsif TokenPattern.wildcard?(term.pattern)
              rows = TokenCountQuery.wildcard_aggregate(
                db,
                pattern: term.pattern,
                search_selection: selection,
                case_sensitive: term.case_sensitive
              )
              count_wildcard(rows, term)
            else
              count_exact(db, term, selection: selection)
            end

          ResultRow.new(
            pattern: term.pattern,
            case_sensitive: term.case_sensitive,
            count: count,
            wildcard: TokenPattern.wildcard?(term.pattern),
            scope: scope_label,
            spellings: spellings,
            exclude: term.exclude
          )
        end
      end

      private

      def resolve_selection(search_selection, scope, bucket)
        return search_selection if search_selection.is_a?(SearchSelection)

        SearchSelection.from_legacy(scope: scope, bucket: bucket)
      end

      def bulk_antimention_exclude?(pattern)
        pattern.to_s.match?(/\AANTIMENTIONS OF (JAMES|JOHN|JESUS)/i)
      end

      def scan_with_word_stream(word_stream, terms, selection, scope_label)
        Array(terms).map do |term|
          count, spellings = count_term_with_word_stream(word_stream, term, selection)
          ResultRow.new(
            pattern: term.pattern,
            case_sensitive: term.case_sensitive,
            count: count,
            wildcard: TokenPattern.wildcard?(term.pattern),
            scope: scope_label,
            spellings: spellings,
            exclude: term.exclude
          )
        end
      end

      def count_term_with_word_stream(word_stream, term, selection)
        if PhraseQuery.phrase?(term.pattern)
          positions = word_stream.phrase_positions(
            term.pattern,
            case_sensitive: term.case_sensitive,
            selection: selection
          )
          spellings = phrase_spellings_from_stream_positions(
            word_stream,
            positions,
            term.pattern
          )
          [spellings.values.sum, spellings]
        else
          positions = word_stream.positions_for(
            term.pattern,
            case_sensitive: term.case_sensitive,
            selection: selection
          )
          spellings = spellings_from_stream_positions(word_stream, positions, term.pattern)
          [spellings.values.sum, spellings]
        end
      end

      def spellings_from_stream_positions(word_stream, positions, _pattern)
        tallies = Hash.new(0)
        positions.each do |position|
          token = word_stream.token_at(position)
          next unless token

          tallies[token.token_raw] += 1
        end
        tallies.sort_by { |raw, count| [-count, raw] }.to_h
      end

      def phrase_spellings_from_stream_positions(word_stream, positions, pattern)
        words = PhraseQuery.phrase_words(pattern)
        tallies = Hash.new(0)
        positions.each do |start|
          phrase_raw = words.length.times.map do |offset|
            word_stream.token_at(start + offset).token_raw
          end.join(" ")
          tallies[phrase_raw] += 1
        end
        tallies.sort_by { |phrase, count| [-count, phrase] }.to_h
      end

      def count_exact(db, term, selection:)
        spellings = TokenCountQuery.spellings_for_token(
          db,
          token: term.pattern,
          search_selection: selection,
          case_sensitive: term.case_sensitive
        )
        [spellings.values.sum, spellings]
      end

      def count_wildcard(rows, term)
        spellings = {}
        rows.each do |row|
          next unless TokenPattern.matches?(
            term.pattern,
            token_raw: row[:token_raw],
            token_norm: row[:token_norm],
            case_sensitive: term.case_sensitive
          )

          spellings[row[:token_raw]] = row[:count]
        end
        [spellings.values.sum, spellings.sort_by { |raw, count| [-count, raw] }.to_h]
      end
    end
  end
end
