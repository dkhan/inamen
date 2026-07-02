# frozen_string_literal: true

module Inamen
  # Default CLI summary: bucket totals in the public-facing layout.
  module SummaryReport
    COVER_TITLE_LINES = ["HOLY BIBLE", "KING JAMES VERSION"].freeze

    def self.format_count(n)
      n.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    def self.text_word_breakdown(lines)
      entries, buckets, _total = TextWordsDebugReport.collect(lines)
      cover = 0
      book_titles = 0

      entries.each do |e|
        next unless e[:classification] == :book_title

        if COVER_TITLE_LINES.include?(e[:raw].to_s.strip)
          cover += e[:tokens]
        else
          book_titles += e[:tokens]
        end
      end

      {
        cover_title_words: cover,
        book_title_words: book_titles,
        colophon_words: buckets[:colophon]
      }
    end

    def self.build(lines)
      counts = CountingService.total_for_lines(lines)
      tw = text_word_breakdown(lines)

      {
        verse_text_words: counts[:verse_text_words],
        psalm_heading_words: counts[:psalm_heading_words],
        colophon_words: tw[:colophon_words],
        cover_title_words: tw[:cover_title_words],
        book_title_words: tw[:book_title_words],
        total_chapters: counts[:chapter_numbers],
        total_verses: counts[:verse_numbers],
        psalm_119_inscriptions: counts[:psalm_119_division_words],
        total: CountingService.combined_total(counts)
      }
    end

    def self.print_summary(lines, out: $stdout)
      s = build(lines)
      rows = [
        [s[:verse_text_words], "WORDS IN VERSE TEXT"],
        [s[:psalm_heading_words], "WORDS IN PSALM HEADINGS"],
        [s[:colophon_words], "WORDS IN COLOPHONS"],
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
