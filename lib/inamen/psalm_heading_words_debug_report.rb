# frozen_string_literal: true

module Inamen
  # Lines that add to +psalm_heading_words+ in CountingService.total_for_lines (same state machine).
  module PsalmHeadingWordsDebugReport
    def self.collect(lines)
      entries = []
      total = 0

      expecting_implicit_psalm_verse_1 = false
      expecting_split_verse_body = false
      prev_nonempty_stripped = nil

      lines.each_with_index do |line, i|
        s = line.to_s.strip
        next if s.empty?

        if expecting_split_verse_body
          expecting_split_verse_body = false
          prev_nonempty_stripped = s
          next
        end

        if PsalmHeading.stanza_label?(s)
          expecting_implicit_psalm_verse_1 = true
          prev_nonempty_stripped = s
          next
        end

        if s.match?(CountingService::PSALM_TITLE)
          expecting_implicit_psalm_verse_1 = true
          prev_nonempty_stripped = s
          next
        end

        if expecting_implicit_psalm_verse_1
          if PsalmHeading.match?(s)
            tok = Tokenizer.tokenize(s).size
            total += tok
            entries << { lineno: i + 1, raw: line.to_s.chomp, tokens: tok }
            prev_nonempty_stripped = s
            next
          end
          if s.match?(CountingService::VERSE_LINE)
            expecting_implicit_psalm_verse_1 = false
            prev_nonempty_stripped = s
            next
          end
          r = CountingService.implicit_psalm_unnumbered_resolution(lines, i, s)
          if (h = r[:psalm_heading_words]).positive?
            total += h
            entries << { lineno: i + 1, raw: line.to_s.chomp, tokens: h }
          end
          expecting_implicit_psalm_verse_1 = false if r[:clear_waiting]
          prev_nonempty_stripped = s
          next
        end

        ch = CountingService::CHAPTER_LINE
        if prev_nonempty_stripped&.match?(ch) && s.match?(ch)
          expecting_split_verse_body = true
          prev_nonempty_stripped = s
          next
        end

        prev_nonempty_stripped = s
      end

      [entries, total]
    end

    def self.print_report(lines, out: $stdout)
      entries, total = collect(lines)

      out.puts "Lines contributing to psalm_heading_words (#{entries.size} lines)"
      out.puts

      entries.each do |e|
        out.puts "L#{e[:lineno]}\t#{e[:tokens]} tok"
        out.puts "  #{e[:raw]}"
        out.puts
      end

      out.puts "Total psalm_heading_words: #{total}"
    end
  end
end
