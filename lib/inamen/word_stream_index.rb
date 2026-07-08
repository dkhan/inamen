# frozen_string_literal: true

require_relative "token_pattern"
require_relative "phrase_query"

module Inamen
  # KJPBS-style flat word stream with per-token posting lists for instant phrase search.
  class WordStreamIndex
    FORMAT_VERSION = 2
    ROW_BOOK = 0
    ROW_CHAPTER = 1
    ROW_VERSE = 2
    ROW_BUCKET = 3
    ROW_WORD_INDEX = 4
    ROW_NORM = 5
    ROW_RAW = 6

    Token = Struct.new(:book, :chapter, :verse, :bucket, :word_index, :token_norm, :token_raw, keyword_init: true)
    VerseHitGroup = Struct.new(:book, :chapter, :verse, :bucket, :indices, keyword_init: true) do
      def verse_key
        [book, chapter, verse, bucket]
      end
    end

    @edition_indexes = {}

    class << self
      def build_from_db(db)
        token_rows = []
        postings_norm = Hash.new { |hash, key| hash[key] = [] }
        postings_raw = Hash.new { |hash, key| hash[key] = [] }

        db.execute(<<~SQL).each do |book, chapter, verse, word_index, token_raw, token_norm, bucket|
          SELECT book, chapter, verse, word_index, token_raw, token_norm, bucket
          FROM tokens
          ORDER BY book, chapter, verse, bucket, word_index
        SQL
          position = token_rows.length
          token_rows << [book, chapter.to_i, verse.to_i, bucket, word_index.to_i, token_norm, token_raw]
          postings_norm[token_norm] << position
          postings_raw[token_raw] << position
        end

        new(
          token_rows: token_rows.freeze,
          postings_norm: postings_norm.transform_values(&:freeze).freeze,
          postings_raw: postings_raw.transform_values(&:freeze).freeze
        )
      end

      def load_dump(data)
        if data[:format] == FORMAT_VERSION
          new(
            token_rows: data.fetch(:token_rows),
            postings_norm: data.fetch(:postings_norm),
            postings_raw: data.fetch(:postings_raw)
          )
        else
          rows = data.fetch(:tokens).map do |token|
            [token.book, token.chapter, token.verse, token.bucket, token.word_index, token.token_norm, token.token_raw]
          end
          new(
            token_rows: rows,
            postings_norm: data.fetch(:postings_norm),
            postings_raw: data.fetch(:postings_raw)
          )
        end
      end

      def load_from_file(path)
        load_dump(Marshal.load(File.binread(path))) # rubocop:disable Security/MarshalLoad
      end

      def clear_cache!
        @edition_indexes = {}
      end

      def for_edition(cache_key, prebuilt_path:)
        @edition_indexes[cache_key] ||= load_from_file(prebuilt_path)
      end
    end

    attr_reader :token_rows, :postings_norm, :postings_raw

    def initialize(token_rows:, postings_norm:, postings_raw:)
      @token_rows = token_rows
      @postings_norm = postings_norm
      @postings_raw = postings_raw
    end

    def dump
      {
        format: FORMAT_VERSION,
        token_rows: token_rows,
        postings_norm: postings_norm,
        postings_raw: postings_raw
      }
    end

    def size
      token_rows.length
    end

    def tokens
      token_rows
    end

    def token_at(position)
      row = token_rows[position]
      return nil unless row

      Token.new(
        book: row[ROW_BOOK],
        chapter: row[ROW_CHAPTER],
        verse: row[ROW_VERSE],
        bucket: row[ROW_BUCKET],
        word_index: row[ROW_WORD_INDEX],
        token_norm: row[ROW_NORM],
        token_raw: row[ROW_RAW]
      )
    end

    def positions_for(pattern, case_sensitive:, selection:)
      if TokenPattern.wildcard?(pattern)
        wildcard_positions(pattern, case_sensitive: case_sensitive, selection: selection)
      elsif case_sensitive
        raw = CorpusStore.normalize_apostrophes(pattern)
        filter_positions(postings_raw[raw] || [], selection)
      else
        norm = CorpusStore.normalize_token(pattern)
        filter_positions(postings_norm[norm] || [], selection)
      end
    end

    def phrase_positions(pattern, case_sensitive:, selection:)
      words = PhraseQuery.phrase_words(pattern)
      return [] if words.empty?

      candidates = positions_for(words.first, case_sensitive: case_sensitive, selection: selection)
      return candidates if words.length == 1

      candidates.select do |start|
        words.each_with_index.all? do |word, offset|
          matches_at?(start + offset, word, case_sensitive: case_sensitive)
        end
      end
    end

    def verse_groups_for_term(term, selection:)
      if PhraseQuery.phrase?(term.pattern)
        phrase_verse_groups(term, selection: selection)
      else
        exact_or_wildcard_verse_groups(term, selection: selection)
      end
    end

    def matches_at?(position, pattern, case_sensitive:)
      row = token_rows[position]
      return false unless row

      TokenPattern.matches?(
        pattern,
        token_raw: row[ROW_RAW],
        token_norm: row[ROW_NORM],
        case_sensitive: case_sensitive
      )
    end

    private

    def exact_or_wildcard_verse_groups(term, selection:)
      grouped = Hash.new { |hash, key| hash[key] = [] }
      positions_for(term.pattern, case_sensitive: term.case_sensitive, selection: selection).each do |position|
        row = token_rows[position]
        grouped[[row[ROW_BOOK], row[ROW_CHAPTER], row[ROW_VERSE], row[ROW_BUCKET]]] << row[ROW_WORD_INDEX]
      end

      grouped.map do |(book, chapter, verse, bucket), indices|
        VerseHitGroup.new(book: book, chapter: chapter, verse: verse, bucket: bucket, indices: indices)
      end
    end

    def phrase_verse_groups(term, selection:)
      words = PhraseQuery.phrase_words(term.pattern)
      grouped = Hash.new { |hash, key| hash[key] = [] }

      phrase_positions(term.pattern, case_sensitive: term.case_sensitive, selection: selection).each do |start|
        row = token_rows[start]
        key = [row[ROW_BOOK], row[ROW_CHAPTER], row[ROW_VERSE], row[ROW_BUCKET]]
        (0...words.length).each { |offset| grouped[key] << token_rows[start + offset][ROW_WORD_INDEX] }
      end

      grouped.map do |(book, chapter, verse, bucket), indices|
        VerseHitGroup.new(book: book, chapter: chapter, verse: verse, bucket: bucket, indices: indices)
      end
    end

    def wildcard_positions(pattern, case_sensitive:, selection:)
      regex = TokenPattern.to_regex(pattern, case_sensitive: case_sensitive)
      prefilter = TokenPattern.sql_prefilter(pattern, case_sensitive: case_sensitive)
      candidate_keys =
        if prefilter == :full
          case_sensitive ? postings_raw.keys : postings_norm.keys
        elsif prefilter[:op] == :glob
          glob = prefilter[:value]
          source = case_sensitive ? postings_raw : postings_norm
          source.keys.select { |key| File.fnmatch?(glob, key) }
        else
          like = prefilter[:value]
          postings_norm.keys.select { |key| like_prefilter_match?(like, key) }
        end

      positions = []
      candidate_keys.each do |key|
        list = case_sensitive ? postings_raw[key] : postings_norm[key]
        next if list.nil? || list.empty?

        list.each do |position|
          row = token_rows[position]
          next unless row
          next unless wildcard_token_match?(regex, row, pattern: pattern, case_sensitive: case_sensitive)
          next unless selection.matches_token_fields?(book: row[ROW_BOOK], bucket: row[ROW_BUCKET])

          positions << position
        end
      end
      positions
    end

    def filter_positions(positions, selection)
      positions.select do |position|
        row = token_rows[position]
        row && selection.matches_token_fields?(book: row[ROW_BOOK], bucket: row[ROW_BUCKET])
      end
    end

    def wildcard_token_match?(regex, row, pattern:, case_sensitive:)
      text = case_sensitive ? row[ROW_RAW] : row[ROW_NORM]
      text = CorpusStore.normalize_apostrophes(text)
      text = text.sub(TokenPattern::TRAILING_POSSESSIVE, "") if TokenPattern.strip_trailing_possessive_for_wildcard?(pattern)
      regex.match?(text)
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
  end
end
