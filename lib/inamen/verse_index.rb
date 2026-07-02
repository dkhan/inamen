# frozen_string_literal: true

module Inamen
  # Verse body text keyed by (book, chapter, verse) from the KjvLineParser event stream.
  module VerseIndex
    def self.each_verse(lines)
      return enum_for(:each_verse, lines) unless block_given?

      labels = BookStatsReport.book_label_at_each_index(lines)
      state = { book: nil, chapter: nil, verse: nil }

      KjvLineParser.each_event(lines) do |event|
        b = labels[event.lineno - 1]
        if b != state[:book]
          state[:book] = b
          state[:chapter] = state[:verse] = nil
        end

        prev_chapter = state[:chapter]
        ChapterReport.send(:advance_chapter!, state, event, b)
        state[:verse] = nil if state[:chapter] != prev_chapter && state[:chapter]

        d = event.totals_delta
        s = event.stripped
        case event.kind
        when KjvParseEvent::KIND_NUMBERED_LINE, KjvParseEvent::KIND_VERSE_AFTER_PSALM_HEADING
          state[:verse] = nil if d[:chapter_numbers].to_i.positive?
          state[:verse] = KjvLineParser.verse_line_number(s) if d[:verse_numbers].to_i.positive?
        when KjvParseEvent::KIND_IMPLICIT_PSALM_OPENING
          state[:verse] = 1 if d[:implicit_psalm_verse_1].to_i.positive? || d[:verse_numbers].to_i.positive?
        when KjvParseEvent::KIND_SPLIT_VERSE_NUMBER
          state[:verse] = s.to_i
        end

        next unless d[:verse_text_words].to_i.positive?
        next unless state[:book] && state[:chapter] && state[:verse]

        text = verse_body_from_stripped(s)
        yield state[:book], state[:chapter], state[:verse], text
      end
    end

    def self.verse_text(lines, book:, chapter:, verse:)
      target = [book.to_s, Integer(chapter), Integer(verse)]
      each_verse(lines) do |b, ch, v, text|
        return text if [b, ch, v] == target
      end
      nil
    end

    def self.name_token_indices(text, name_prefix)
      re = /\A#{Regexp.escape(name_prefix)}/i
      Tokenizer.tokenize(text).each_with_index.filter_map { |tok, i| i + 1 if tok.match?(re) }
    end

    def self.verse_body_from_stripped(stripped)
      s = stripped.to_s
      if s.match?(CountingService::VERSE_LINE)
        s.sub(/\A\d+\s+/, "")
      else
        s
      end
    end
    private_class_method :verse_body_from_stripped
  end
end
