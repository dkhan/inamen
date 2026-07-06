# frozen_string_literal: true

module Inamen
  # Count token occurrences for one or more search patterns (exact or * wildcard).
  module TokenQuery
    QueryTerm = Struct.new(:pattern, :case_sensitive, keyword_init: true)
    ResultRow = Struct.new(:pattern, :case_sensitive, :count, :wildcard, :scope, :spellings, keyword_init: true)

    MAX_TERMS = 100

    class << self
      def parse_terms(text)
        terms = text.to_s.each_line.filter_map { |line| TokenPattern.parse_line(line) }.map do |attrs|
          QueryTerm.new(**attrs)
        end
        raise ArgumentError, "at least one search term required" if terms.empty?
        raise ArgumentError, "too many terms (max #{MAX_TERMS})" if terms.length > MAX_TERMS

        terms
      end

      def scan(db, terms:, scope: :whole_bible, bucket: :default)
        scope_label = TokenCountQuery.scope_label(scope)
        Array(terms).map do |term|
          count, spellings =
            if TokenPattern.wildcard?(term.pattern)
              rows = TokenCountQuery.wildcard_aggregate(
                db,
                pattern: term.pattern,
                scope: scope,
                bucket: bucket,
                case_sensitive: term.case_sensitive
              )
              count_wildcard(rows, term)
            else
              count_exact(db, term, scope: scope, bucket: bucket)
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

      def count_exact(db, term, scope:, bucket:)
        spellings = TokenCountQuery.spellings_for_token(
          db,
          token: term.pattern,
          scope: scope,
          bucket: bucket,
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
