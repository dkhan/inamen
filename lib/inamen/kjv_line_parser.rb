# frozen_string_literal: true

module Inamen
  # Canonical line-by-line traversal of KJV-shaped text. Yields one KjvParseEvent per non-empty line.
  class KjvLineParser
    CHAPTER_LINE = CountingService::CHAPTER_LINE
    CHAPTER_WORD_LINE = CountingService::CHAPTER_WORD_LINE
    VERSE_LINE = CountingService::VERSE_LINE
    PSALM_TITLE = CountingService::PSALM_TITLE

    def self.each_event(lines)
      state = ParserState.new
      lines.each_with_index do |line, i|
        s = KjvLine.strip(line)
        next if s.empty?

        yield advance!(lines, i, line, s, state)
      end
    end

    def self.each_step(lines, &block)
      each_event(lines, &block)
    end

    def self.advance!(lines, i, line, s, state)
      nb = BookStatsReport.book_at(lines, i)
      state.current_book = nb if nb

      if canonical_book_line?(s)
        state.prev_nonempty_stripped = s
        return build_event(
          KjvParseEvent::KIND_BOOK_TITLE,
          lines, i, line, s,
          totals_delta: Totals.empty.to_h
        )
      end

      if state.expecting_split_verse_body
        tok = Tokenizer.tokenize(s).size
        state.expecting_split_verse_body = false
        state.prev_nonempty_stripped = s
        return build_event(
          KjvParseEvent::KIND_SPLIT_VERSE_BODY,
          lines, i, line, s,
          totals_delta: { verse_text_words: tok }
        )
      end

      if PsalmHeading.stanza_label?(s)
        word_count = PsalmHeading.stanza_word_count(s)
        division_count = PsalmHeading.stanza_division_count(s)
        state.expecting_implicit_psalm_verse_1 = true
        state.prev_nonempty_stripped = s
        return build_event(
          KjvParseEvent::KIND_PSALM_119_DIVISION,
          lines, i, line, s,
          totals_delta: { text_words: word_count, psalm_119_division_words: division_count }
        )
      end

      if psalm_chapter_line?(s, state)
        state.expecting_implicit_psalm_verse_1 = true
        state.prev_nonempty_stripped = s
        return build_event(
          KjvParseEvent::KIND_PSALM_TITLE,
          lines, i, line, s,
          totals_delta: psalm_chapter_totals_delta(s, state),
          book_chapters: 1
        )
      end

      if state.expecting_implicit_psalm_verse_1
        classification = LineClassifier.classify(s)
        if classification == :colophon
          state.prev_nonempty_stripped = s
          return colophon_line_step(lines, i, line, s)
        end

        if superscription_line?(s, classification, state)
          heading_text = imported_superscription_text(s)
          tok = Tokenizer.tokenize(heading_text).size
          state.prev_nonempty_stripped = s
          return build_event(
            KjvParseEvent::KIND_PSALM_HEADING,
            lines, i, line, s,
            totals_delta: { psalm_heading_words: tok },
            psalm_heading_debug: { lineno: i + 1, raw: line.to_s.chomp, tokens: tok }
          )
        end

        if s.match?(VERSE_LINE)
          state.expecting_implicit_psalm_verse_1 = false
          partial = CountingService.counts_for_line(s)
          state.prev_nonempty_stripped = s
          return numbered_line_step(
            lines, i, line, s, partial,
            kind: KjvParseEvent::KIND_VERSE_AFTER_PSALM_HEADING
          )
        end

        r = implicit_psalm_unnumbered_resolution(lines, i, s, in_psalms: state.in_psalms?)
        state.expecting_implicit_psalm_verse_1 = false if r.clear_waiting
        state.prev_nonempty_stripped = s
        dbg = nil
        dbg = { lineno: i + 1, raw: line.to_s.chomp, tokens: r.psalm_heading_words } if r.psalm_heading_words.positive?
        return build_event(
          KjvParseEvent::KIND_IMPLICIT_PSALM_OPENING,
          lines, i, line, s,
          totals_delta: {
            verse_numbers: r.verse_numbers,
            implicit_psalm_verse_1: r.implicit_psalm_verse_1,
            verse_text_words: r.verse_text_words,
            psalm_heading_words: r.psalm_heading_words
          },
          book_verses: r.verse_numbers,
          psalm_heading_debug: dbg
        )
      end

      if (m = s.match(CHAPTER_WORD_LINE))
        state.expecting_implicit_verse_1_after_chapter = true
        state.prev_nonempty_stripped = s
        return build_event(
          KjvParseEvent::KIND_CHAPTER_TITLE,
          lines, i, line, s,
          totals_delta: {
            chapter_numbers: 1,
            numeric_chapter_lines: 1
          },
          book_chapters: 1,
          numeric_chapter_debug: {
            lineno: i + 1,
            raw: line.to_s,
            prev_raw: prior_non_empty_line(lines, i),
            next_raw: following_non_empty_line(lines, i),
            chapter_number: m[1].to_i
          }
        )
      end

      if state.expecting_implicit_verse_1_after_chapter
        classification = LineClassifier.classify(s)
        if classification == :colophon
          state.prev_nonempty_stripped = s
          return colophon_line_step(lines, i, line, s)
        end

        if superscription_line?(s, classification, state)
          state.prev_nonempty_stripped = s
          return imported_superscription_line_step(lines, i, line, s)
        end

        if s.match?(VERSE_LINE)
          state.expecting_implicit_verse_1_after_chapter = false
          partial = CountingService.counts_for_line(s)
          state.prev_nonempty_stripped = s
          return numbered_line_step(lines, i, line, s, partial)
        end

        r = implicit_chapter_unnumbered_resolution(lines, i, s)
        state.expecting_implicit_verse_1_after_chapter = false if r.clear_waiting
        state.prev_nonempty_stripped = s
        return build_event(
          KjvParseEvent::KIND_IMPLICIT_CHAPTER_OPENING,
          lines, i, line, s,
          totals_delta: {
            verse_numbers: r.verse_numbers,
            implicit_chapter_verse_1: r.implicit_chapter_verse_1,
            verse_text_words: r.verse_text_words
          },
          book_verses: r.verse_numbers
        )
      end

      if split_verse_number_after_chapter?(state.prev_nonempty_stripped, s)
        state.expecting_split_verse_body = true
        state.prev_nonempty_stripped = s
        return build_event(
          KjvParseEvent::KIND_SPLIT_VERSE_NUMBER,
          lines, i, line, s,
          totals_delta: {
            verse_numbers: 1,
            numbered_verse_lines: 1
          },
          book_verses: 1
        )
      end

      partial = CountingService.counts_for_line(s)
      state.prev_nonempty_stripped = s
      numbered_line_step(lines, i, line, s, partial)
    end

    def self.numbered_line_step(lines, i, line, s, partial, kind: KjvParseEvent::KIND_NUMBERED_LINE)
      ev = build_event(
        kind,
        lines, i, line, s,
        totals_delta: {
          text_words: partial[:text_words],
          verse_text_words: partial[:verse_text_words],
          chapter_numbers: partial[:chapter_numbers],
          verse_numbers: partial[:verse_numbers],
          numeric_chapter_lines: partial[:chapter_numbers],
          numbered_verse_lines: partial[:verse_numbers]
        },
        book_chapters: partial[:chapter_numbers],
        book_verses: partial[:verse_numbers]
      )

      if partial[:chapter_numbers].positive?
        ev.numeric_chapter_debug = {
          lineno: i + 1,
          raw: line.to_s,
          prev_raw: prior_non_empty_line(lines, i),
          next_raw: following_non_empty_line(lines, i)
        }
      end

      if partial[:text_words].positive?
        ev.text_words_debug = {
          lineno: i + 1,
          raw: line.to_s.chomp,
          tokens: partial[:text_words],
          classification: LineClassifier.classify(line)
        }
      end

      ev
    end

    def self.colophon_line_step(lines, i, line, s)
      build_event(
        KjvParseEvent::KIND_NUMBERED_LINE,
        lines, i, line, s,
        totals_delta: {
          text_words: Tokenizer.tokenize(s).size,
          verse_text_words: 0,
          chapter_numbers: 0,
          verse_numbers: 0,
          numeric_chapter_lines: 0,
          numbered_verse_lines: 0
        },
        text_words_debug: {
          lineno: i + 1,
          raw: line.to_s.chomp,
          tokens: Tokenizer.tokenize(s).size,
          classification: :colophon
        }
      )
    end

    def self.imported_superscription_line_step(lines, i, line, s)
      text = imported_superscription_text(s)
      tok = Tokenizer.tokenize(text).size
      build_event(
        KjvParseEvent::KIND_PSALM_HEADING,
        lines, i, line, s,
        totals_delta: { psalm_heading_words: tok },
        psalm_heading_debug: { lineno: i + 1, raw: line.to_s.chomp, tokens: tok }
      )
    end

    def self.imported_superscription_text(text)
      text.to_s.delete_prefix(LineClassifier::IMPORTED_SUPERSCRIPTION_PREFIX)
    end

    def self.canonical_book_line?(stripped)
      BibleBooks::ALL.include?(stripped)
    end

    def self.superscription_line?(stripped, classification, state)
      return false unless classification == :psalm_heading

      state.in_psalms? || stripped.start_with?(LineClassifier::IMPORTED_SUPERSCRIPTION_PREFIX)
    end

    def self.build_event(kind, lines, i, line, s, totals_delta:, book_chapters: 0, book_verses: 0,
                         numeric_chapter_debug: nil, text_words_debug: nil, psalm_heading_debug: nil)
      KjvParseEvent.new(
        kind: kind,
        lineno: i + 1,
        raw: line.to_s,
        stripped: s,
        totals_delta: totals_delta,
        book_chapters: book_chapters,
        book_verses: book_verses,
        numeric_chapter_debug: numeric_chapter_debug,
        text_words_debug: text_words_debug,
        psalm_heading_debug: psalm_heading_debug
      )
    end
    private_class_method :build_event

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

    def self.split_verse_number_after_chapter?(prev_nonempty_stripped, stripped)
      prev = prev_nonempty_stripped.to_s
      prev.match?(CHAPTER_LINE) && stripped.match?(CHAPTER_LINE)
    end

    ImplicitChapterResolution = Struct.new(
      :clear_waiting, :verse_numbers, :implicit_chapter_verse_1, :verse_text_words, keyword_init: true
    )

    def self.implicit_chapter_unnumbered_resolution(lines, line_index, s)
      tok = Tokenizer.tokenize(s).size
      nxt = next_non_empty_stripped(lines, line_index)

      if nxt && (vn = verse_line_number(nxt)) && vn >= 2
        return ImplicitChapterResolution.new(
          clear_waiting: true,
          verse_numbers: 1,
          implicit_chapter_verse_1: 1,
          verse_text_words: tok
        )
      end

      if nxt && CountingService.chapter_marker_line?(nxt)
        return ImplicitChapterResolution.new(
          clear_waiting: true,
          verse_numbers: 1,
          implicit_chapter_verse_1: 1,
          verse_text_words: tok
        )
      end

      if nxt
        return ImplicitChapterResolution.new(
          clear_waiting: false,
          verse_numbers: 0,
          implicit_chapter_verse_1: 0,
          verse_text_words: 0
        )
      end

      ImplicitChapterResolution.new(
        clear_waiting: true,
        verse_numbers: 1,
        implicit_chapter_verse_1: 1,
        verse_text_words: tok
      )
    end

    def self.psalm_chapter_line?(stripped, state)
      CountingService.psalm_chapter_line?(stripped, in_psalms: state.in_psalms?)
    end
    private_class_method :psalm_chapter_line?

    def self.psalm_chapter_totals_delta(stripped, state)
      if stripped.match?(PSALM_TITLE)
        { chapter_numbers: 1, psalm_chapter_titles: 1 }
      elsif state.in_psalms?
        { chapter_numbers: 1, psalm_chapter_titles: 1 }
      else
        { chapter_numbers: 1, numeric_chapter_lines: 1 }
      end
    end
    private_class_method :psalm_chapter_totals_delta

    def self.implicit_psalm_unnumbered_resolution(lines, line_index, s, in_psalms: false)
      tok = Tokenizer.tokenize(s).size
      nxt = next_non_empty_stripped(lines, line_index)

      if nxt && (vn = verse_line_number(nxt)) && vn >= 2
        return ImplicitPsalmResolution.new(
          clear_waiting: true,
          verse_numbers: 1,
          implicit_psalm_verse_1: 1,
          verse_text_words: tok,
          psalm_heading_words: 0
        )
      end

      if nxt && verse_line_number(nxt) == 1
        return ImplicitPsalmResolution.new(
          clear_waiting: false,
          verse_numbers: 0,
          implicit_psalm_verse_1: 0,
          verse_text_words: 0,
          psalm_heading_words: tok
        )
      end

      if nxt && (nxt.match?(PSALM_TITLE) || (in_psalms && nxt.match?(CHAPTER_LINE)))
        return ImplicitPsalmResolution.new(
          clear_waiting: true,
          verse_numbers: 1,
          implicit_psalm_verse_1: 1,
          verse_text_words: tok,
          psalm_heading_words: 0
        )
      end

      if nxt
        return ImplicitPsalmResolution.new(
          clear_waiting: false,
          verse_numbers: 0,
          implicit_psalm_verse_1: 0,
          verse_text_words: 0,
          psalm_heading_words: tok
        )
      end

      ImplicitPsalmResolution.new(
        clear_waiting: true,
        verse_numbers: 1,
        implicit_psalm_verse_1: 1,
        verse_text_words: tok,
        psalm_heading_words: 0
      )
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
  end
end
