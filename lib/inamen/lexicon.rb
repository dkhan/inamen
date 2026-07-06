# frozen_string_literal: true

require_relative "corpus_store"
require_relative "token_pattern"

module Inamen
  # In-memory token count index loaded from the materialized token_counts table.
  class Lexicon
    Row = Struct.new(:token_norm, :token_raw, :count, keyword_init: true)

    @cache = {}

    class << self
      def for(db, search_selection:)
        return unless CorpusStore.token_counts_available?(db)

        key = cache_key(db, search_selection)
        @cache[key] ||= new(db, search_selection)
      end

      def clear_cache!
        @cache = {}
      end

      def cache_key(db, selection)
        path = db.respond_to?(:filename) ? db.filename.to_s : db.object_id
        [path, selection.cache_key]
      end
    end

    attr_reader :selection

    def initialize(db, selection)
      @selection = selection
      @rows_norm_raw = load_rows(db, selection)
      @by_norm = build_by_norm(@rows_norm_raw)
    end

    def aggregate(group: :norm_raw)
      case group
      when :norm
        @by_norm.map do |token_norm, spellings|
          { token_norm: token_norm, token_raw: nil, count: spellings.values.sum }
        end
      else
        @rows_norm_raw.map { |row| row.to_h }
      end
    end

    def spellings_for_token(token:, case_sensitive:)
      if case_sensitive
        raw = CorpusStore.normalize_apostrophes(token.to_s)
        count = @rows_norm_raw.find { |row| row.token_raw == raw }&.count
        count ? { raw => count } : {}
      else
        (@by_norm[CorpusStore.normalize_token(token)] || {}).sort_by { |raw, c| [-c, raw] }.to_h
      end
    end

    def wildcard_rows(pattern, case_sensitive:)
      regex = TokenPattern.to_regex(pattern, case_sensitive: case_sensitive)
      prefilter_rows(pattern, case_sensitive: case_sensitive).select do |row|
        wildcard_row_match?(regex, row, case_sensitive: case_sensitive)
      end
    end

    private

    def prefilter_rows(pattern, case_sensitive:)
      prefilter = TokenPattern.sql_prefilter(pattern, case_sensitive: case_sensitive)
      return @rows_norm_raw if prefilter == :full

      case prefilter[:op]
      when :like
        like_prefilter_rows(prefilter[:value])
      when :glob
        glob = prefilter[:value]
        @rows_norm_raw.select { |row| File.fnmatch?(glob, row.token_raw) }
      end
    end

    def like_prefilter_rows(like_value)
      @rows_norm_raw.select { |row| like_prefilter_match?(like_value, row.token_norm) }
    end

    def like_prefilter_match?(like_value, token_norm)
      parts = like_value.split("%")
      return true if parts.all?(&:empty?)

      index = 0
      parts.each_with_index do |part, i|
        next if part.empty?

        pos = token_norm.index(part, index)
        return false unless pos
        return false if i.zero? && !like_value.start_with?("%") && pos.positive?

        index = pos + part.length
      end
      return false if !like_value.end_with?("%") && index != token_norm.length

      true
    end

    def wildcard_row_match?(regex, row, case_sensitive:)
      text = case_sensitive ? row.token_raw : row.token_norm
      text = CorpusStore.normalize_apostrophes(text)
      text = text.sub(TokenPattern::TRAILING_POSSESSIVE, "")
      regex.match?(text)
    end

    def load_rows(db, selection)
      where_sql, where_params = selection.where_clause
      sql = <<~SQL
        SELECT token_norm, token_raw, SUM(count) AS count
        FROM token_counts
        WHERE 1=1 #{where_sql}
        GROUP BY token_norm, token_raw
      SQL

      db.execute(sql, where_params).map do |token_norm, token_raw, count|
        Row.new(token_norm: token_norm, token_raw: token_raw, count: count.to_i)
      end
    end

    def build_by_norm(rows)
      rows.each_with_object(Hash.new { |h, k| h[k] = {} }) do |row, index|
        index[row.token_norm][row.token_raw] = row.count
      end
    end
  end
end
