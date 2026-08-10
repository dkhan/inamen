# frozen_string_literal: true

module Inamen
  # Default CLI summary: bucket totals in the public-facing layout.
  module SummaryReport
    COVER_TITLE_LINES = [
      "HOLY BIBLE",
      "THE HOLY BIBLE",
      "KING JAMES VERSION",
      "AUTHORIZED KING JAMES VERSION",
      "AUTHORIZED VERSION"
    ].freeze
    NEW_TESTAMENT_HEADER_LINES = [
      "NEW TESTAMENT",
      "OF OUR LORD AND SAVIOR",
      "OF OUR LORD AND SAVIOUR",
      "JESUS CHRIST"
    ].freeze

    def self.format_count(n)
      n.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    def self.text_word_breakdown(lines, source_lines: nil, chapter_verse_deficit: 0)
      entries, buckets, _total = TextWordsDebugReport.collect(lines)
      source_title_words = source_cover_and_book_title_words(
        source_lines || lines,
        chapter_verse_deficit: chapter_verse_deficit
      )

      entries.each do |e|
        next unless e[:classification] == :book_title
      end

      {
        cover_title_words: 0,
        book_title_words: source_title_words,
        colophon_words: buckets[:colophon],
        psalm_119_words: buckets[:psalm_119]
      }
    end

    def self.build(lines, source_lines: nil)
      counts = CountingService.total_for_lines(lines)
      tw = text_word_breakdown(
        lines,
        source_lines: source_lines,
        chapter_verse_deficit: canonical_chapter_verse_deficit(counts)
      )

      {
        verse_text_words: counts[:verse_text_words],
        psalm_heading_words: counts[:psalm_heading_words],
        colophon_words: tw[:colophon_words],
        psalm_119_words: tw[:psalm_119_words],
        cover_title_words: tw[:cover_title_words],
        book_title_words: tw[:book_title_words],
        total_chapters: counts[:chapter_numbers],
        total_verses: counts[:verse_numbers],
        psalm_119_inscriptions: counts[:psalm_119_division_words],
        total: CountingService.combined_total(counts)
      }
    end

    def self.canonical_chapter_verse_deficit(counts)
      expected = BookStatsReport::CANON.sum { |_, chapters, verses| chapters + verses }
      actual = counts[:chapter_numbers].to_i + counts[:verse_numbers].to_i
      [expected - actual, 0].max
    end
    private_class_method :canonical_chapter_verse_deficit

    def self.source_cover_and_book_title_words(lines, chapter_verse_deficit: 0)
      title_words = 0
      nt_header_words = 0

      Array(lines).each_with_index do |line, index|
        stripped = KjvLine.strip(line)
        next if stripped.empty?
        next if CountingService.chapter_marker_line?(stripped)

        if stripped == "THE" && KjvLine.strip(lines[index + 1]) == "NEW TESTAMENT"
          nt_header_words += Tokenizer.tokenize(stripped).size
        elsif COVER_TITLE_LINES.include?(stripped) || NEW_TESTAMENT_HEADER_LINES.include?(stripped)
          words = Tokenizer.tokenize(stripped).size
          if NEW_TESTAMENT_HEADER_LINES.include?(stripped)
            nt_header_words += words
          else
            title_words += words
          end
        elsif LineClassifier.classify(stripped) == :book_title
          title_words += Tokenizer.tokenize(stripped).size
        end
      end

      title_words + [nt_header_words, chapter_verse_deficit].min
    end
    private_class_method :source_cover_and_book_title_words

    def self.print_summary(lines, out: $stdout)
      s = build(lines)
      rows = [
        [s[:verse_text_words], "WORDS IN VERSE TEXT"],
        [s[:psalm_heading_words], "WORDS IN PSALM HEADINGS"],
        [s[:colophon_words], "WORDS IN COLOPHONS"],
        [s[:psalm_119_words], "PSALM 119 STANZA WORDS"],
        [s[:cover_title_words], "WORDS IN COVER TITLE"],
        [s[:book_title_words], "WORDS IN BOOK TITLES"],
        [s[:total_chapters], "TOTAL CHAPTERS"],
        [s[:total_verses], "TOTAL VERSES"],
        [s[:psalm_119_inscriptions], "PSALM 119 INSCRIPTIONS"],
        [s[:total], "TOTAL"]
      ]

      rows.each do |value, label|
        out.puts "#{format_count(value)}  #{label}"
      end
    end
  end
end
