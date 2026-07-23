# frozen_string_literal: true

require_relative "corpus_store"
require_relative "search_selection"
require_relative "token_pattern"

module Inamen
  # Count consecutive-word phrases (e.g. "Jesus Christ", "Jesus Chris*") in the token stream.
  module PhraseQuery
    MAX_WORDS = 20

    class << self
      def phrase?(pattern)
        phrase_words(pattern).length > 1
      end

      def count(db, pattern:, search_selection:, case_sensitive:)
        words = phrase_words(pattern)
        raise ArgumentError, "phrase too long (max #{MAX_WORDS} words)" if words.length > MAX_WORDS

        selection = resolve_selection(search_selection)
        spellings = spellings_for_phrase(db, words:, selection:, case_sensitive:)
        [spellings.values.sum, spellings]
      end

      def positions(db, pattern:, search_selection:, case_sensitive:)
        words = phrase_words(pattern)
        raise ArgumentError, "phrase too long (max #{MAX_WORDS} words)" if words.length > MAX_WORDS

        selection = resolve_selection(search_selection)
        rows_for_phrase(db, words:, selection:, case_sensitive:).map do |row|
          {
            book: row[:book],
            chapter: row[:chapter],
            verse: row[:verse],
            bucket: row[:bucket],
            word_index: row[:word_index],
            word_count: words.length
          }
        end
      end

      def phrase_words(pattern)
        CorpusStore.normalize_apostrophes(pattern.to_s.strip).split(/\s+/).reject(&:empty?)
      end

      private

      def resolve_selection(search_selection)
        return search_selection if search_selection.is_a?(SearchSelection)

        SearchSelection.default
      end

      def spellings_for_phrase(db, words:, selection:, case_sensitive:)
        grouped = rows_for_phrase(db, words:, selection:, case_sensitive:)
        spellings = Hash.new(0)
        grouped.each { |row| spellings[row[:phrase_raw]] += 1 }
        spellings.sort_by { |phrase, phrase_count| [-phrase_count, phrase] }.to_h
      end

      def rows_for_phrase(db, words:, selection:, case_sensitive:)
        where_sql, where_params = selection.where_clause
        qualified_where = qualify_where_clause(where_sql)

        joins_sql = (1...words.length).map do |index|
          "JOIN tokens t#{index} ON t#{index}.book = t0.book " \
            "AND t#{index}.chapter = t0.chapter AND t#{index}.verse = t0.verse " \
            "AND t#{index}.bucket = t0.bucket AND t#{index}.word_index = t0.word_index + #{index}"
        end.join("\n")

        word_sql = words.each_with_index.map do |word, index|
          word_condition(word, index, case_sensitive: case_sensitive)
        end

        select_cols = (0...words.length).flat_map { |index| ["t#{index}.token_raw", "t#{index}.token_norm"] }
        select_cols.concat(%w[t0.book t0.chapter t0.verse t0.bucket t0.word_index])

        sql = <<~SQL
          SELECT #{select_cols.join(", ")}
          FROM tokens t0
          #{joins_sql}
          WHERE 1=1 #{qualified_where}
            AND #{word_sql.map(&:first).join(' AND ')}
          ORDER BY t0.book, t0.chapter, t0.verse, t0.bucket, t0.word_index
        SQL

        params = where_params + word_sql.flat_map(&:last)
        rows = []

        db.execute(sql, params).each do |row|
          values = row.dup
          location = values.pop(5)
          book, chapter, verse, bucket, word_index = location
          raws = words.length.times.map { |index| values[index * 2] }
          norms = words.length.times.map { |index| values[(index * 2) + 1] }
          next unless phrase_matches?(words, raws, norms, case_sensitive: case_sensitive)

          rows << {
            book: book,
            chapter: chapter.to_i,
            verse: verse.to_i,
            bucket: bucket,
            word_index: word_index.to_i,
            phrase_raw: raws.join(" ")
          }
        end

        rows
      end

      def word_condition(word, index, case_sensitive:)
        if TokenPattern.wildcard?(word)
          prefilter = TokenPattern.sql_prefilter(word, case_sensitive: case_sensitive)
          raise ArgumentError, "unsupported wildcard word in phrase: #{word.inspect}" if prefilter == :full

          column = prefilter[:column]
          case prefilter[:op]
          when :like
            ["t#{index}.#{column} LIKE ? ESCAPE '\\'", [prefilter[:value]]]
          when :glob
            ["t#{index}.#{column} GLOB ?", [prefilter[:value]]]
          end
        elsif case_sensitive
          values = CorpusStore.apostrophe_equivalent_strings(word)
          placeholders = (["?"] * values.length).join(", ")
          ["t#{index}.token_raw IN (#{placeholders})", values]
        else
          ["t#{index}.token_norm = ?", CorpusStore.normalize_token(word)]
        end
      end

      def phrase_matches?(words, raws, norms, case_sensitive:)
        words.each_with_index.all? do |word, index|
          TokenPattern.matches?(
            word,
            token_raw: raws[index],
            token_norm: norms[index],
            case_sensitive: case_sensitive
          )
        end
      end

      def qualify_where_clause(where_sql, table: "t0")
        where_sql.gsub(/\bbucket\b/, "#{table}.bucket").gsub(/\bbook\b/, "#{table}.book")
      end
    end
  end
end
