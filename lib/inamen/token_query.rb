# frozen_string_literal: true

module Inamen
  # Count token occurrences for one or more search patterns (exact or * wildcard).
  module TokenQuery
    QueryTerm = Struct.new(:pattern, :case_sensitive, keyword_init: true)
    ResultRow = Struct.new(:pattern, :case_sensitive, :count, :wildcard, :scope, :spellings, keyword_init: true)

    MAX_TERMS = 100

    class << self
      def parse_terms(text)
        terms = text.to_s.each_line.flat_map do |line|
          attrs = TokenPattern.parse_query_line(line)
          next [] unless attrs
          next [] if attrs[:disabled]

          TokenPattern.split_phrase_patterns(attrs[:pattern]).map do |pattern|
            QueryTerm.new(pattern: pattern, case_sensitive: attrs[:case_sensitive])
          end
        end
        raise ArgumentError, "at least one search term required" if terms.empty?
        raise ArgumentError, "too many terms (max #{MAX_TERMS})" if terms.length > MAX_TERMS

        terms
      end

      def scan(db, terms:, search_selection: nil, scope: :whole_bible, bucket: :default)
        selection = resolve_selection(search_selection, scope, bucket)
        scope_label = TokenCountQuery.selection_label(selection)
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
            spellings: spellings
          )
        end
      end

      private

      def resolve_selection(search_selection, scope, bucket)
        return search_selection if search_selection.is_a?(SearchSelection)

        SearchSelection.from_legacy(scope: scope, bucket: bucket)
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
