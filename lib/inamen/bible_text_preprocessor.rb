# frozen_string_literal: true

require "pathname"

require_relative "bible_books"

module Inamen
  # Validates imported Bible-shaped plain text and trims matter outside the corpus.
  class BibleTextPreprocessor
    MAX_BYTES = 10 * 1024 * 1024
    MAX_BOOKS = 100
    CHAPTER_LINE = /\A(?:chapter\s+)?\d+\z/i
    VERSE_LINE = /\A\d+\s+\S/

    Result = Struct.new(:lines, :books, keyword_init: true)

    class Error < StandardError; end

    def self.from_file(path)
      new(path).process
    end

    def initialize(path)
      @path = Pathname(path)
    end

    def process
      validate_file!
      lines = decoded_lines
      processed = []
      books = []
      in_corpus = false
      current_book = nil
      expecting_implicit_opening = false

      lines.each_with_index do |line, index|
        stripped = KjvLine.strip(line)
        next if stripped.empty?

        if (book = book_at(lines, index, stripped))
          books << book unless books.include?(book)
          raise Error, "too many books (max #{MAX_BOOKS})" if books.length > MAX_BOOKS

          in_corpus = true
          current_book = book
          expecting_implicit_opening = false
          processed << book
          next
        end

        next unless in_corpus
        classification = LineClassifier.classify(stripped)
        keep = corpus_line?(stripped, classification, current_book) ||
          (expecting_implicit_opening && implicit_opening_line?(stripped, classification))
        next unless keep

        normalized = normalize_chapter_line(stripped)
        processed << normalized
        expecting_implicit_opening = chapter_or_superscription_line?(normalized, classification, current_book)
      end

      validate_bible_corpus!(processed, books)
      Result.new(lines: processed, books: books)
    end

    private

    def validate_file!
      raise Error, "file does not exist: #{@path}" unless @path.file?
      raise Error, "file is larger than 10 MB" if @path.size > MAX_BYTES

      bytes = @path.binread
      raise Error, "binary files are not supported" if bytes.include?("\x00")

      text = bytes.dup.force_encoding(Encoding::UTF_8)
      raise Error, "invalid UTF-8 encoding" unless text.valid_encoding?

      @text = text
    end

    def decoded_lines
      @text.lines(chomp: true)
    end

    def book_at(lines, index, stripped)
      BookStatsReport.book_at(lines, index) || BibleBooks.canonical_name(stripped)
    end

    def normalize_chapter_line(stripped)
      if (m = stripped.match(/\Achapter\s+(\d+)\z/i))
        "CHAPTER #{m[1]}"
      else
        stripped
      end
    end

    def corpus_line?(stripped, classification, current_book)
      return true if stripped.match?(CHAPTER_LINE)
      return true if psalm_chapter_line?(stripped, current_book)
      return true if stripped.match?(VERSE_LINE)

      %i[psalm_heading psalm_119_division colophon].include?(classification)
    end

    def implicit_opening_line?(stripped, classification)
      return false if classification == :book_title
      return false if stripped.match?(CHAPTER_LINE)
      return false if stripped.match?(VERSE_LINE)

      stripped.match?(/\p{L}/)
    end

    def chapter_or_superscription_line?(line, classification, current_book)
      line.match?(CHAPTER_LINE) ||
        psalm_chapter_line?(line, current_book) ||
        %i[psalm_heading psalm_119_division].include?(classification)
    end

    def psalm_chapter_line?(stripped, current_book)
      current_book == "Psalms" && CountingService.psalm_chapter_line?(stripped, in_psalms: true)
    end

    def chapter_marker?(line)
      line.match?(CHAPTER_LINE) || CountingService.psalm_chapter_line?(line, in_psalms: true)
    end

    def validate_bible_corpus!(lines, books)
      raise Error, "no canonical Bible books found" if books.empty?
      raise Error, "no chapters found" unless lines.any? { |line| chapter_marker?(line) }
      raise Error, "no numbered verses found" unless lines.any? { |line| line.match?(VERSE_LINE) }

      unknown_books = books - BibleBooks::ALL
      raise Error, "unknown books: #{unknown_books.join(', ')}" if unknown_books.any?
    end
  end
end
