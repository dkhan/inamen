# frozen_string_literal: true

module Inamen
  # Counts tokens in KJV-style plain text: chapters, verses, prose, Psalms with optional
  # implicit verse 1, superscriptions, and Psalm 119 stanza labels.
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

    # KJV.txt splits some verse-1 lines: chapter number line, then a lone verse number, then body on the next line.
    def self.split_verse_number_after_chapter?(prev_nonempty_stripped, stripped)
      prev_nonempty_stripped&.match?(CHAPTER_LINE) && stripped.match?(CHAPTER_LINE)
    end
    private_class_method :split_verse_number_after_chapter?

    # Next non-empty stripped line after +lines[line_index]+.
    def self.next_non_empty_stripped(lines, line_index)
      j = line_index + 1
      while j < lines.length
        t = lines[j].to_s.strip
        return t unless t.empty?
        j += 1
      end
      nil
    end

    def self.verse_line_number(stripped)
      (m = stripped.match(VERSE_LINE)) ? m[1].to_i : nil
    end

    # After PSALM n / stanza / heading, how to count a non-numbered line + whether to keep waiting for verse 1.
    # Uses the next non-empty line: numbered verse ≥2 or next PSALM ⇒ this line is implicit verse 1;
    # numbered verse 1 ⇒ this line is more heading; otherwise ⇒ heading until we see a clearer cue.
    def self.implicit_psalm_unnumbered_resolution(lines, line_index, s)
      tok = Tokenizer.tokenize(s).size
      nxt = next_non_empty_stripped(lines, line_index)

      if nxt && (vn = verse_line_number(nxt)) && vn >= 2
        return {
          clear_waiting: true,
          verse_numbers: 1,
          implicit_psalm_verse_1: 1,
          verse_text_words: tok,
          psalm_heading_words: 0
        }
      end

      if nxt && verse_line_number(nxt) == 1
        return {
          clear_waiting: false,
          verse_numbers: 0,
          implicit_psalm_verse_1: 0,
          verse_text_words: 0,
          psalm_heading_words: tok
        }
      end

      if nxt && nxt.match?(PSALM_TITLE)
        return {
          clear_waiting: true,
          verse_numbers: 1,
          implicit_psalm_verse_1: 1,
          verse_text_words: tok,
          psalm_heading_words: 0
        }
      end

      if nxt
        return {
          clear_waiting: false,
          verse_numbers: 0,
          implicit_psalm_verse_1: 0,
          verse_text_words: 0,
          psalm_heading_words: tok
        }
      end

      {
        clear_waiting: true,
        verse_numbers: 1,
        implicit_psalm_verse_1: 1,
        verse_text_words: tok,
        psalm_heading_words: 0
      }
    end

    def self.total_for_lines(lines)
      acc = empty_counts
      expecting_implicit_psalm_verse_1 = false
      expecting_split_verse_body = false
      prev_nonempty_stripped = nil

      lines.each_with_index do |line, i|
        s = line.to_s.strip
        next if s.empty?

        if expecting_split_verse_body
          acc[:verse_text_words] += Tokenizer.tokenize(s).size
          expecting_split_verse_body = false
          prev_nonempty_stripped = s
          next
        end

        if PsalmHeading.stanza_label?(s)
          acc[:psalm_119_division_words] += Tokenizer.tokenize(s).size
          expecting_implicit_psalm_verse_1 = true
          prev_nonempty_stripped = s
          next
        end

        if s.match?(PSALM_TITLE)
          acc[:chapter_numbers] += 1
          acc[:psalm_chapter_titles] += 1
          expecting_implicit_psalm_verse_1 = true
          prev_nonempty_stripped = s
          next
        end

        if expecting_implicit_psalm_verse_1
          if PsalmHeading.match?(s)
            acc[:psalm_heading_words] += Tokenizer.tokenize(s).size
            prev_nonempty_stripped = s
            next
          end
          if s.match?(VERSE_LINE)
            expecting_implicit_psalm_verse_1 = false
            apply_numbered_or_chapter_line!(acc, s)
            prev_nonempty_stripped = s
            next
          end
          r = implicit_psalm_unnumbered_resolution(lines, i, s)
          acc[:verse_numbers] += r[:verse_numbers]
          acc[:implicit_psalm_verse_1] += r[:implicit_psalm_verse_1]
          acc[:verse_text_words] += r[:verse_text_words]
          acc[:psalm_heading_words] += r[:psalm_heading_words]
          expecting_implicit_psalm_verse_1 = false if r[:clear_waiting]
          prev_nonempty_stripped = s
          next
        end

        if split_verse_number_after_chapter?(prev_nonempty_stripped, s)
          acc[:verse_numbers] += 1
          acc[:numbered_verse_lines] += 1
          expecting_split_verse_body = true
          prev_nonempty_stripped = s
          next
        end

        apply_numbered_or_chapter_line!(acc, s)
        prev_nonempty_stripped = s
      end

      acc
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
      {
        text_words: 0,
        verse_text_words: 0,
        psalm_heading_words: 0,
        psalm_119_division_words: 0,
        chapter_numbers: 0,
        verse_numbers: 0,
        psalm_chapter_titles: 0,
        numeric_chapter_lines: 0,
        implicit_psalm_verse_1: 0,
        numbered_verse_lines: 0
      }
    end

    def self.apply_numbered_or_chapter_line!(acc, s)
      partial = counts_for_line(s)
      acc[:text_words] += partial[:text_words]
      acc[:verse_text_words] += partial[:verse_text_words]
      acc[:chapter_numbers] += partial[:chapter_numbers]
      acc[:verse_numbers] += partial[:verse_numbers]
      acc[:numeric_chapter_lines] += partial[:chapter_numbers]
      acc[:numbered_verse_lines] += partial[:verse_numbers]
      acc
    end
    private_class_method :apply_numbered_or_chapter_line!

    # Lines that increment +numeric_chapter_lines+ in +total_for_lines+ (same state machine).
    # Each hash: :lineno (1-based), :raw, :prev_raw, :next_raw (neighboring non-empty lines).
    def self.numeric_chapter_debug_entries(lines)
      entries = []
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

        if s.match?(PSALM_TITLE)
          expecting_implicit_psalm_verse_1 = true
          prev_nonempty_stripped = s
          next
        end

        if expecting_implicit_psalm_verse_1
          if PsalmHeading.match?(s)
            prev_nonempty_stripped = s
            next
          end
          if s.match?(VERSE_LINE)
            expecting_implicit_psalm_verse_1 = false
            prev_nonempty_stripped = s
            next
          end
          r = implicit_psalm_unnumbered_resolution(lines, i, s)
          expecting_implicit_psalm_verse_1 = false if r[:clear_waiting]
          prev_nonempty_stripped = s
          next
        end

        if split_verse_number_after_chapter?(prev_nonempty_stripped, s)
          expecting_split_verse_body = true
          prev_nonempty_stripped = s
          next
        end

        if counts_for_line(s)[:chapter_numbers].positive?
          entries << {
            lineno: i + 1,
            raw: line.to_s,
            prev_raw: prior_non_empty_line(lines, i),
            next_raw: following_non_empty_line(lines, i)
          }
        end
        prev_nonempty_stripped = s
      end

      entries
    end

    def self.prior_non_empty_line(lines, idx)
      (idx - 1).downto(0) do |j|
        return lines[j] unless lines[j].to_s.strip.empty?
      end
      nil
    end

    def self.following_non_empty_line(lines, idx)
      ((idx + 1)...lines.length).each do |j|
        return lines[j] unless lines[j].to_s.strip.empty?
      end
      nil
    end
    private_class_method :prior_non_empty_line, :following_non_empty_line
  end
end
