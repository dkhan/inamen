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
      "ПЕРВАЯ КНИГА МОИСЕЕВА БЫТИЕ" => "Genesis",
      "Бытие" => "Genesis",
      "ВТОРАЯ КНИГА МОИСЕЕВА ИСХОД" => "Exodus",
      "Исход" => "Exodus",
      "ТРЕТЬЯ КНИГА МОИСЕЕВА ЛЕВИТ" => "Leviticus",
      "Левит" => "Leviticus",
      "ЧЕТВЕРТАЯ КНИГА МОИСЕЕВА ЧИСЛА" => "Numbers",
      "Числа" => "Numbers",
      "ПЯТАЯ КНИГА МОИСЕЕВА ВТОРОЗАКОНИЕ" => "Deuteronomy",
      "Второзаконие" => "Deuteronomy",
      "КНИГА ИИСУСА НАВИНА" => "Joshua",
      "Книга Иисуса Навина" => "Joshua",
      "КНИГА СУДЕЙ ИЗРАИЛЕВЫХ" => "Judges",
      "Книга Судей израилевых" => "Judges",
      "КНИГА РУФЬ" => "Ruth",
      "Книга Руфи" => "Ruth",
      "ПЕРВАЯ КНИГА ЦАРСТВ" => "1 Samuel",
      "Первая книга Царств" => "1 Samuel",
      "ВТОРАЯ КНИГА ЦАРСТВ" => "2 Samuel",
      "Вторая книга Царств" => "2 Samuel",
      "ТРЕТЬЯ КНИГА ЦАРСТВ" => "1 Kings",
      "Третья книга Царств" => "1 Kings",
      "ЧЕТВЕРТАЯ КНИГА ЦАРСТВ" => "2 Kings",
      "Четвертая книга Царств" => "2 Kings",
      "ПЕРВАЯ КНИГА ПАРАЛИПОМЕНОН" => "1 Chronicles",
      "Первая книга Паралипоменон" => "1 Chronicles",
      "ВТОРАЯ КНИГА ПАРАЛИПОМЕНОН" => "2 Chronicles",
      "Вторая книга Паралипоменон" => "2 Chronicles",
      "ПЕРВАЯ КНИГА ЕЗДРЫ" => "Ezra",
      "Первая книга Ездры" => "Ezra",
      "КНИГА НЕЕМИИ" => "Nehemiah",
      "Книга Неемии" => "Nehemiah",
      "Вторая книга Ездры" => "1 Esdras",
      "Книга Товита" => "Tobit",
      "Книга Иудифи" => "Judith",
      "КНИГА ЕСФИРЬ" => "Esther",
      "Книга Есфири" => "Esther",
      "КНИГА ИОВА" => "Job",
      "Книга Иова" => "Job",
      "ПСАЛТИРЬ" => "Psalms",
      "Псалтирь" => "Psalms",
      "КНИГА ПРИТЧЕЙ СОЛОМОНОВЫХ" => "Proverbs",
      "Притчи Соломона" => "Proverbs",
      "КНИГА ЕККЛЕСИАСТА ИЛИ ПРОПОВЕДНИКА" => "Ecclesiastes",
      "Книга Екклезиаста" => "Ecclesiastes",
      "КНИГА ПЕСНИ ПЕСНЕЙ СОЛОМОНОВЫХ" => "Song of Solomon",
      "Песнь песней Соломона" => "Song of Solomon",
      "Книга Премудрости Соломона" => "Wisdom of Solomon",
      "Книга Премудрости Иисуса, сына Сирахова" => "Sirach",
      "КНИГА ПРОРОКА ИСАИИ" => "Isaiah",
      "Книга пророка Исаии" => "Isaiah",
      "КНИГА ПРОРОКА ИЕРЕМИИ" => "Jeremiah",
      "Книга пророка Иеремии" => "Jeremiah",
      "КНИГА ПЛАЧ ИЕРЕМИИ" => "Lamentations",
      "Плач Иеремии" => "Lamentations",
      "Послание Иеремии" => "Letter of Jeremiah",
      "Книга пророка Варуха" => "Baruch",
      "КНИГА ПРОРОКА ИЕЗЕКИИЛЯ" => "Ezekiel",
      "Книга пророка Иезекииля" => "Ezekiel",
      "КНИГА ПРОРОКА ДАНИИЛА" => "Daniel",
      "Книга пророка Даниила" => "Daniel",
      "КНИГА ПРОРОКА ОСИИ" => "Hosea",
      "Книга пророка Осии" => "Hosea",
      "КНИГА ПРОРОКА ИОИЛЯ" => "Joel",
      "Книга пророка Иоиля" => "Joel",
      "КНИГА ПРОРОКА АМОСА" => "Amos",
      "Книга пророка Амоса" => "Amos",
      "КНИГА ПРОРОКА АВДИЯ" => "Obadiah",
      "Книга пророка Авдия" => "Obadiah",
      "КНИГА ПРОРОКА ИОНЫ" => "Jonah",
      "Книга пророка Ионы" => "Jonah",
      "КНИГА ПРОРОКА МИХЕЯ" => "Micah",
      "Книга пророка Михея" => "Micah",
      "КНИГА ПРОРОКА НАУМА" => "Nahum",
      "Книга пророка Наума" => "Nahum",
      "КНИГА ПРОРОКА АВВАКУМА" => "Habakkuk",
      "Книга пророка Аввакума" => "Habakkuk",
      "КНИГА ПРОРОКА СОФОНИИ" => "Zephaniah",
      "Книга пророка Софонии" => "Zephaniah",
      "КНИГА ПРОРОКА АГГЕЯ" => "Haggai",
      "Книга пророка Аггея" => "Haggai",
      "КНИГА ПРОРОКА ЗАХАРИИ" => "Zechariah",
      "Книга пророка Захарии" => "Zechariah",
      "КНИГА ПРОРОКА МАЛАХИИ" => "Malachi",
      "Книга пророка Малахии" => "Malachi",
      "Первая книга Маккавейская" => "1 Maccabees",
      "Вторая книга Маккавейская" => "2 Maccabees",
      "Третья книга Маккавейская" => "3 Maccabees",
      "Третья книга Ездры" => "2 Esdras",
      "ОТ МАТФЕЯ СВЯТОЕ БЛАГОВЕСТВОВАНИЕ" => "Matthew",
      "От Матфея святое благовествование" => "Matthew",
      "ОТ МАРКА СВЯТОЕ БЛАГОВЕСТВОВАНИЕ" => "Mark",
      "От Марка святое благовествование" => "Mark",
      "ОТ ЛУКИ СВЯТОЕ БЛАГОВЕСТВОВАНИЕ" => "Luke",
      "От Луки святое благовествование" => "Luke",
      "ОТ ИОАННА СВЯТОЕ БЛАГОВЕСТВОВАНИЕ" => "John",
      "От Иоанна святое благовествование" => "John",
      "ДЕЯНИЯ СВЯТЫХ АПОСТОЛОВ" => "Acts",
      "Деяния святых апостолов" => "Acts",
      "СОБОРНОЕ ПОСЛАНИЕ СВЯТОГО АПОСТОЛА ИАКОВА" => "James",
      "Соборное послание святого апостола Иакова" => "James",
      "ПЕРВОЕ СОБОРНОЕ ПОСЛАНИЕ СВЯТОГО АПОСТОЛА ПЕТРА" => "1 Peter",
      "Первое соборное послание святого апостола Петра" => "1 Peter",
      "ВТОРОЕ СОБОРНОЕ ПОСЛАНИЕ СВЯТОГО АПОСТОЛА ПЕТРА" => "2 Peter",
      "Второе соборное послание святого апостола Петра" => "2 Peter",
      "ПЕРВОЕ СОБОРНОЕ ПОСЛАНИЕ СВЯТОГО АПОСТОЛА ИОАННА" => "1 John",
      "Первое соборное послание святого апостола Иоанна" => "1 John",
      "ВТОРОЕ СОБОРНОЕ ПОСЛАНИЕ СВЯТОГО АПОСТОЛА ИОАННА" => "2 John",
      "Второе соборное послание святого апостола Иоанна" => "2 John",
      "ТРЕТЬЕ СОБОРНОЕ ПОСЛАНИЕ СВЯТОГО АПОСТОЛА ИОАННА" => "3 John",
      "Третье соборное послание святого апостола Иоанна" => "3 John",
      "СОБОРНОЕ ПОСЛАНИЕ СВЯТОГО АПОСТОЛА ИУДЫ" => "Jude",
      "Соборное послание святого апостола Иуды" => "Jude",
      "ПОСЛАНИЕ К РИМЛЯНАМ СВЯТОГО АПОСТОЛА ПАВЛА" => "Romans",
      "Послание к Римлянам святого апостола Павла" => "Romans",
      "ПЕРВОЕ ПОСЛАНИЕ К КОРИНФЯНАМ СВЯТОГО АПОСТОЛА ПАВЛА" => "1 Corinthians",
      "Первое послание к Коринфянам святого апостола Павла" => "1 Corinthians",
      "ВТОРОЕ ПОСЛАНИЕ К КОРИНФЯНАМ СВЯТОГО АПОСТОЛА ПАВЛА" => "2 Corinthians",
      "Второе послание к Коринфянам святого апостола Павла" => "2 Corinthians",
      "ПОСЛАНИЕ К ГАЛАТАМ СВЯТОГО АПОСТОЛА ПАВЛА" => "Galatians",
      "Послание к Галатам святого апостола Павла" => "Galatians",
      "ПОСЛАНИЕ К ЕФЕСЯНАМ СВЯТОГО АПОСТОЛА ПАВЛА" => "Ephesians",
      "Послание к Ефесянам святого апостола Павла" => "Ephesians",
      "ПОСЛАНИЕ К ФИЛИППИЙЦАМ СВЯТОГО АПОСТОЛА ПАВЛА" => "Philippians",
      "Послание к Филиппийцам святого апостола Павла" => "Philippians",
      "ПОСЛАНИЕ К КОЛОССЯНАМ СВЯТОГО АПОСТОЛА ПАВЛА" => "Colossians",
      "Послание к Колоссянам святого апостола Павла" => "Colossians",
      "ПЕРВОЕ ПОСЛАНИЕ К ФЕССАЛОНИКИЙЦАМ СВЯТОГО АПОСТОЛА ПАВЛА" => "1 Thessalonians",
      "Первое послание к Фессалоникийцам (Солунянам) святого апостола Павла" => "1 Thessalonians",
      "ВТОРОЕ ПОСЛАНИЕ К ФЕССАЛОНИКИЙЦАМ СВЯТОГО АПОСТОЛА ПАВЛА" => "2 Thessalonians",
      "Второе послание к Фессалоникийцам (Солунянам) святого апостола Павла" => "2 Thessalonians",
      "ПЕРВОЕ ПОСЛАНИЕ К ТИМОФЕЮ СВЯТОГО АПОСТОЛА ПАВЛА" => "1 Timothy",
      "Первое послание к Тимофею святого апостола Павла" => "1 Timothy",
      "ВТОРОЕ ПОСЛАНИЕ К ТИМОФЕЮ СВЯТОГО АПОСТОЛА ПАВЛА" => "2 Timothy",
      "Второе послание к Тимофею святого апостола Павла" => "2 Timothy",
      "ПОСЛАНИЕ К ТИТУ СВЯТОГО АПОСТОЛА ПАВЛА" => "Titus",
      "Послание к Титу святого апостола Павла" => "Titus",
      "ПОСЛАНИЕ К ФИЛИМОНУ СВЯТОГО АПОСТОЛА ПАВЛА" => "Philemon",
      "Послание к Филимону святого апостола Павла" => "Philemon",
      "ПОСЛАНИЕ К ЕВРЕЯМ СВЯТОГО АПОСТОЛА ПАВЛА" => "Hebrews",
      "Послание к Евреям святого апостола Павла" => "Hebrews",
      "ОТКРОВЕНИЕ СВЯТОГО ИОАННА БОГОСЛОВА" => "Revelation",
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
      lines.first(500).any? { |line| RUSSIAN_BOOK_TITLES.key?(normalize_russian_title(line)) }
    end

    def process_russian_synodal(lines)
      processed = []
      books = []
      current_book = nil
      current_verse = nil
      current_psalm_heading = nil
      special_section = false
      skip_until = -1

      flush_verse = lambda do
        next unless current_verse

        processed << current_verse
        current_verse = nil
      end

      flush_psalm_heading = lambda do
        next unless current_psalm_heading

        processed << current_psalm_heading
        current_psalm_heading = nil
      end

      lines.each_with_index do |line, index|
        next if index <= skip_until

        stripped = KjvLine.strip(line)
        next if stripped.empty?

        if (match = russian_book_at(lines, index))
          flush_verse.call
          flush_psalm_heading.call
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
          flush_psalm_heading.call
          special_section = true
          processed << special_line(stripped)
          next
        end

        if stripped.match?(CHAPTER_LINE)
          flush_verse.call
          flush_psalm_heading.call
          special_section = false
          processed << (current_book == "Psalms" ? "PSALM #{stripped}" : "CHAPTER #{stripped}")
          next
        end

        if special_section
          flush_verse.call
          flush_psalm_heading.call
          processed << special_line(stripped)
          next
        end

        if current_book == "Psalms"
          if (heading = russian_psalm_heading_start(stripped))
            flush_verse.call
            current_psalm_heading = append_text(current_psalm_heading, heading)
            next
          elsif current_psalm_heading && !stripped.match?(RUSSIAN_VERSE_LINE)
            current_psalm_heading = append_text(current_psalm_heading, stripped)
            next
          end
        end

        if current_book == "Sirach" && current_verse&.end_with?(" Молитва Иисуса,") && stripped == "сына Сирахова"
          current_verse.delete_suffix!(" Молитва Иисуса,")
          flush_verse.call
          flush_psalm_heading.call
          processed << special_line("Молитва Иисуса, сына Сирахова")
          next
        end

        if (m = stripped.match(RUSSIAN_VERSE_LINE))
          flush_psalm_heading.call
          flush_verse.call
          current_verse = "#{m[1]} #{m[2]}"
        elsif current_verse
          current_verse << " #{stripped}"
        end
      end

      flush_psalm_heading.call
      flush_verse.call
      validate_bible_corpus!(processed, books)
      Result.new(lines: processed, books: books, language: "ru", canon: russian_synodal_canon(books))
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

    def russian_synodal_canon(books)
      books.length == 66 ? "russian_synodal_66" : "russian_synodal_77"
    end

    def russian_psalm_heading_start(stripped)
      candidate = stripped.sub(/\A1\s+/, "")
      return candidate if PsalmHeading.match?(candidate)

      nil
    end

    def append_text(base, addition)
      return addition.to_s if base.nil? || base.empty?

      "#{base} #{addition}"
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
