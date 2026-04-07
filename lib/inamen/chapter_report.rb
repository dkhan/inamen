# frozen_string_literal: true

module Inamen
  # Per-chapter stats from the KjvLineParser event stream (same counting rules as global totals).
  module ChapterReport
    PSALM_TITLE_RE = /\APSALM (\d+)\z/

    def self.canonical_book_name(name)
      n = name.to_s.strip
      return nil if n.empty?

      BookStatsReport::CANON.find { |(book, _, _)| book.casecmp?(n) }&.first
    end

    # Returns hash: :book, :chapter, :verse_count, :verse_text_words, :combined, :divisible_by_7
    def self.stats_for_chapter(lines, book:, chapter:)
      target_book = canonical_book_name(book)
      raise ArgumentError, "Unknown book: #{book.inspect}" unless target_book

      ch = Integer(chapter)
      raise ArgumentError, "Chapter must be positive" unless ch.positive?

      labels = BookStatsReport.book_label_at_each_index(lines)
      totals = Totals.empty
      state = { book: nil, chapter: nil }

      KjvLineParser.each_event(lines) do |event|
        idx = event.lineno - 1
        b = labels[idx]

        if b != state[:book]
          state[:book] = b
          state[:chapter] = nil
        end

        advance_chapter!(state, event, b)

        next unless b == target_book && state[:chapter] == ch

        totals.add_partial!(event.totals_delta)
      end

      h = totals.to_h
      verse_count = h[:verse_numbers] + h[:implicit_psalm_verse_1]
      combined = CountingService.combined_total(h)

      {
        book: target_book,
        chapter: ch,
        verse_count: verse_count,
        verse_text_words: h[:verse_text_words],
        combined: combined,
        divisible_by_7: (combined % 7).zero?
      }
    end

    def self.advance_chapter!(state, event, book)
      s = event.stripped

      if book == "Psalms"
        if event.kind == KjvParseEvent::KIND_PSALM_TITLE && (m = s.match(PSALM_TITLE_RE))
          state[:chapter] = m[1].to_i
        end
      elsif s.match?(CountingService::CHAPTER_LINE)
        state[:chapter] = s.to_i
      end
    end
    private_class_method :advance_chapter!

    def self.print_chapter(lines, book:, chapter:, out: $stdout)
      s = stats_for_chapter(lines, book: book, chapter: chapter)
      out.puts "Book: #{s[:book]}"
      out.puts "Chapter: #{s[:chapter]}"
      out.puts "Verse count: #{s[:verse_count]}"
      out.puts "Verse text words: #{s[:verse_text_words]}"
      out.puts "Chapter total: #{s[:combined]}"
      out.puts "Divisible by 7: #{s[:divisible_by_7]}"
    end
  end
end
