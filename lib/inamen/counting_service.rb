# frozen_string_literal: true

module Inamen
  # Token labeling and orchestration; line traversal lives in KjvLineParser.
  class CountingService
    CHAPTER_LINE = /\A\d+\z/
    VERSE_LINE = /\A(\d+)\s+(.+)\z/m
    PSALM_TITLE = /\APSALM [0-9]+\z/

    # Each entry is [category, token_string] with category one of
    # :chapter_number, :verse_number, :text_word, :verse_text_word.
    def self.labeled_tokens_for_line(line)
      stripped = line.to_s.strip
      return [] if stripped.empty?

      if stripped.match?(CHAPTER_LINE)
        [[:chapter_number, stripped]]
      elsif (m = stripped.match(VERSE_LINE))
        [[:verse_number, m[1]]] + Tokenizer.tokenize(m[2]).map { |t| [:verse_text_word, t] }
      else
        Tokenizer.tokenize(stripped).map { |t| [:text_word, t] }
      end
    end

    def self.counts_for_line(line)
      labels = labeled_tokens_for_line(line)
      {
        text_words: labels.count { |(c, _)| c == :text_word },
        verse_text_words: labels.count { |(c, _)| c == :verse_text_word },
        psalm_heading_words: 0,
        psalm_119_division_words: 0,
        chapter_numbers: labels.count { |(c, _)| c == :chapter_number },
        verse_numbers: labels.count { |(c, _)| c == :verse_number }
      }
    end

    def self.total_for_lines(lines)
      totals = Totals.empty
      KjvLineParser.each_event(lines) do |event|
        totals.add_partial!(event.totals_delta)
      end
      totals.to_h
    end

    def self.combined_total(counts)
      counts[:text_words] +
        counts[:psalm_heading_words] +
        counts[:psalm_119_division_words] +
        counts[:verse_text_words] +
        counts[:chapter_numbers] +
        counts[:verse_numbers]
    end

    def self.empty_counts
      Totals.empty.to_h
    end

    # --- Delegates to KjvLineParser (shared with reports) ---

    def self.next_non_empty_stripped(lines, line_index)
      KjvLineParser.next_non_empty_stripped(lines, line_index)
    end

    def self.verse_line_number(stripped)
      KjvLineParser.verse_line_number(stripped)
    end

    def self.split_verse_number_after_chapter?(prev_nonempty_stripped, stripped)
      KjvLineParser.split_verse_number_after_chapter?(prev_nonempty_stripped, stripped)
    end

    def self.implicit_psalm_unnumbered_resolution(lines, line_index, s)
      KjvLineParser.implicit_psalm_unnumbered_resolution(lines, line_index, s)
    end

    def self.numeric_chapter_debug_entries(lines)
      entries = []
      KjvLineParser.each_event(lines) do |event|
        next unless event.numeric_chapter_debug

        d = event.numeric_chapter_debug
        entries << {
          lineno: d[:lineno],
          raw: d[:raw],
          prev_raw: d[:prev_raw],
          next_raw: d[:next_raw]
        }
      end
      entries
    end
  end
end
