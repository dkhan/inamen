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

    Result = Struct.new(:lines, :books, :language, :canon, keyword_init: true)

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
      return process_russian_synodal(lines) if russian_synodal?(lines)

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
      Result.new(lines: processed, books: books, language: "en", canon: "generic")
    end

    private

    RUSSIAN_BOOK_TITLES = {
      "Бытие" => "Genesis",
      "Исход" => "Exodus",
      "Левит" => "Leviticus",
      "Числа" => "Numbers",
      "Второзаконие" => "Deuteronomy",
      "Книга Иисуса Навина" => "Joshua",
      "Книга Судей израилевых" => "Judges",
      "Книга Руфи" => "Ruth",
      "Первая книга Царств" => "1 Samuel",
      "Вторая книга Царств" => "2 Samuel",
      "Третья книга Царств" => "1 Kings",
      "Четвертая книга Царств" => "2 Kings",
      "Первая книга Паралипоменон" => "1 Chronicles",
      "Вторая книга Паралипоменон" => "2 Chronicles",
      "Первая книга Ездры" => "Ezra",
      "Книга Неемии" => "Nehemiah",
      "Вторая книга Ездры" => "1 Esdras",
      "Книга Товита" => "Tobit",
      "Книга Иудифи" => "Judith",
      "Книга Есфири" => "Esther",
      "Книга Иова" => "Job",
      "Псалтирь" => "Psalms",
      "Притчи Соломона" => "Proverbs",
      "Книга Екклезиаста" => "Ecclesiastes",
      "Песнь песней Соломона" => "Song of Solomon",
      "Книга Премудрости Соломона" => "Wisdom of Solomon",
      "Книга Премудрости Иисуса, сына Сирахова" => "Sirach",
      "Книга пророка Исаии" => "Isaiah",
      "Книга пророка Иеремии" => "Jeremiah",
      "Плач Иеремии" => "Lamentations",
      "Послание Иеремии" => "Letter of Jeremiah",
      "Книга пророка Варуха" => "Baruch",
      "Книга пророка Иезекииля" => "Ezekiel",
      "Книга пророка Даниила" => "Daniel",
      "Книга пророка Осии" => "Hosea",
      "Книга пророка Иоиля" => "Joel",
      "Книга пророка Амоса" => "Amos",
      "Книга пророка Авдия" => "Obadiah",
      "Книга пророка Ионы" => "Jonah",
      "Книга пророка Михея" => "Micah",
      "Книга пророка Наума" => "Nahum",
      "Книга пророка Аввакума" => "Habakkuk",
      "Книга пророка Софонии" => "Zephaniah",
      "Книга пророка Аггея" => "Haggai",
      "Книга пророка Захарии" => "Zechariah",
      "Книга пророка Малахии" => "Malachi",
      "Первая книга Маккавейская" => "1 Maccabees",
      "Вторая книга Маккавейская" => "2 Maccabees",
      "Третья книга Маккавейская" => "3 Maccabees",
      "Третья книга Ездры" => "2 Esdras",
      "От Матфея святое благовествование" => "Matthew",
      "От Марка святое благовествование" => "Mark",
      "От Луки святое благовествование" => "Luke",
      "От Иоанна святое благовествование" => "John",
      "Деяния святых апостолов" => "Acts",
      "Соборное послание святого апостола Иакова" => "James",
      "Первое соборное послание святого апостола Петра" => "1 Peter",
      "Второе соборное послание святого апостола Петра" => "2 Peter",
      "Первое соборное послание святого апостола Иоанна" => "1 John",
      "Второе соборное послание святого апостола Иоанна" => "2 John",
      "Третье соборное послание святого апостола Иоанна" => "3 John",
      "Соборное послание святого апостола Иуды" => "Jude",
      "Послание к Римлянам святого апостола Павла" => "Romans",
      "Первое послание к Коринфянам святого апостола Павла" => "1 Corinthians",
      "Второе послание к Коринфянам святого апостола Павла" => "2 Corinthians",
      "Послание к Галатам святого апостола Павла" => "Galatians",
      "Послание к Ефесянам святого апостола Павла" => "Ephesians",
      "Послание к Филиппийцам святого апостола Павла" => "Philippians",
      "Послание к Колоссянам святого апостола Павла" => "Colossians",
      "Первое послание к Фессалоникийцам (Солунянам) святого апостола Павла" => "1 Thessalonians",
      "Второе послание к Фессалоникийцам (Солунянам) святого апостола Павла" => "2 Thessalonians",
      "Первое послание к Тимофею святого апостола Павла" => "1 Timothy",
      "Второе послание к Тимофею святого апостола Павла" => "2 Timothy",
      "Послание к Титу святого апостола Павла" => "Titus",
      "Послание к Филимону святого апостола Павла" => "Philemon",
      "Послание к Евреям святого апостола Павла" => "Hebrews",
      "Откровение святого Иоанна Богослова" => "Revelation"
    }.freeze

    RUSSIAN_VERSE_LINE = /\A(\d+)\s+(.+)\z/m
    INTERNAL_SPECIAL_PREFIX = LineClassifier::IMPORTED_SPECIAL_PREFIX

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

    def russian_synodal?(lines)
      lines.first(100).any? { |line| normalize_russian_title(line) == "Бытие" }
    end

    def process_russian_synodal(lines)
      processed = []
      books = []
      current_book = nil
      current_verse = nil
      special_section = false
      skip_until = -1

      flush_verse = lambda do
        next unless current_verse

        processed << current_verse
        current_verse = nil
      end

      lines.each_with_index do |line, index|
        next if index <= skip_until

        stripped = KjvLine.strip(line)
        next if stripped.empty?

        if (match = russian_book_at(lines, index))
          flush_verse.call
          book, consumed = match
          books << book unless books.include?(book)
          raise Error, "too many books (max #{MAX_BOOKS})" if books.length > MAX_BOOKS

          processed << book
          current_book = book
          special_section = false
          skip_until = index + consumed - 1
          next
        end

        next unless current_book

        if russian_special_heading?(stripped)
          flush_verse.call
          special_section = true
          processed << special_line(stripped)
          next
        end

        if stripped.match?(CHAPTER_LINE)
          flush_verse.call
          special_section = false
          processed << (current_book == "Psalms" ? "PSALM #{stripped}" : "CHAPTER #{stripped}")
          next
        end

        if special_section
          flush_verse.call
          processed << special_line(stripped)
          next
        end

        if (m = stripped.match(RUSSIAN_VERSE_LINE))
          flush_verse.call
          current_verse = "#{m[1]} #{m[2]}"
        elsif current_verse
          current_verse << " #{stripped}"
        end
      end

      flush_verse.call
      validate_bible_corpus!(processed, books)
      Result.new(lines: processed, books: books, language: "ru", canon: "russian_synodal_77")
    end

    def russian_book_at(lines, index)
      current = normalize_russian_title(lines[index])
      if (book = RUSSIAN_BOOK_TITLES[current])
        return [book, 1]
      end

      following = next_non_empty_line(lines, index + 1)
      return nil unless following

      combined = normalize_russian_title("#{current} #{following.first}")
      book = RUSSIAN_BOOK_TITLES[combined]
      [book, following.last - index + 1] if book
    end

    def next_non_empty_line(lines, start_index)
      (start_index...lines.length).each do |idx|
        stripped = KjvLine.strip(lines[idx])
        return [stripped, idx] unless stripped.empty?
      end
      nil
    end

    def normalize_russian_title(text)
      text.to_s
          .unicode_normalize(:nfkc)
          .strip
          .delete_suffix("*")
          .strip
          .squeeze(" ")
    end

    def russian_special_heading?(stripped)
      stripped == "Предисловие" || stripped.start_with?("[МОЛИТВА МАНАССИИ")
    end

    def special_line(stripped)
      "#{INTERNAL_SPECIAL_PREFIX}#{stripped}"
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
