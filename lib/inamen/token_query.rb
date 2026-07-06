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
          count, spellings = count_with_spellings(db, term, scope: scope, bucket: bucket)
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

      def count_with_spellings(db, term, scope:, bucket:)
        if TokenPattern.wildcard?(term.pattern)
          count_wildcard(db, term, scope: scope, bucket: bucket)
        else
          count_exact(db, term, scope: scope, bucket: bucket)
        end
      end

      def count_exact(db, term, scope:, bucket:)
        rows = TokenCountQuery.aggregate(db, scope: scope, bucket: bucket, group: :norm_raw)
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
        [spellings.values.sum, spellings.sort_by { |raw, c| [-c, raw] }.to_h]
      end

      def count_wildcard(db, term, scope:, bucket:)
        rows = TokenCountQuery.aggregate(db, scope: scope, bucket: bucket, group: :norm_raw)
        spellings = {}
        total = 0
        rows.each do |row|
          next unless TokenPattern.matches?(
            term.pattern,
            token_raw: row[:token_raw],
            token_norm: row[:token_norm],
            case_sensitive: term.case_sensitive
          )

          spellings[row[:token_raw]] = row[:count]
          total += row[:count]
        end
        [total, spellings.sort_by { |raw, c| [-c, raw] }.to_h]
      end
    end
  end
end
