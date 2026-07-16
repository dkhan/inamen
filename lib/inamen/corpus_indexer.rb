# frozen_string_literal: true

module Inamen
  # Walks the KjvLineParser event stream and yields token records for corpus indexing.
  module CorpusIndexer
    def self.each_token_record(lines, &block)
      return enum_for(:each_token_record, lines) unless block

      labels = BookStatsReport.book_label_at_each_index(lines)
      state = { book: nil, chapter: nil, verse: nil }
      verse_buffers = {}

      KjvLineParser.each_event(lines) do |event|
        book = labels[event.lineno - 1]
        if book != state[:book]
          state[:book] = book
          state[:chapter] = state[:verse] = nil
        end

        prev_chapter = state[:chapter]
        ChapterReport.send(:advance_chapter!, state, event, book)
        state[:verse] = nil if state[:chapter] != prev_chapter && state[:chapter]

        d = event.totals_delta
        s = event.stripped
        case event.kind
        when KjvParseEvent::KIND_NUMBERED_LINE, KjvParseEvent::KIND_VERSE_AFTER_PSALM_HEADING
          state[:verse] = nil if d[:chapter_numbers].to_i.positive?
          state[:verse] = KjvLineParser.verse_line_number(s) if d[:verse_numbers].to_i.positive?
        when KjvParseEvent::KIND_IMPLICIT_PSALM_OPENING
          state[:verse] = 1 if d[:implicit_psalm_verse_1].to_i.positive? || d[:verse_numbers].to_i.positive?
        when KjvParseEvent::KIND_IMPLICIT_CHAPTER_OPENING
          state[:verse] = 1 if d[:implicit_chapter_verse_1].to_i.positive? || d[:verse_numbers].to_i.positive?
        when KjvParseEvent::KIND_SPLIT_VERSE_NUMBER
          state[:verse] = s.to_i
        end

        next unless book && CorpusStore::TESTAMENT_BY_BOOK.key?(book)

        testament = CorpusStore.testament_for(book)
        chapter = state[:chapter] || 0

        if event.kind == KjvParseEvent::KIND_PSALM_HEADING
          emit_line_tokens(block, book, chapter, 0, s, CorpusStore::BUCKET_PSALM_HEADING, testament,
                           event.lineno)
        elsif event.kind == KjvParseEvent::KIND_IMPLICIT_PSALM_OPENING && d[:psalm_heading_words].to_i.positive?
          emit_line_tokens(block, book, chapter, 0, s, CorpusStore::BUCKET_PSALM_HEADING, testament,
                           event.lineno)
        elsif colophon_event?(event)
          emit_line_tokens(block, book, chapter, 0, special_text(s), CorpusStore::BUCKET_COLOPHON, testament,
                           event.lineno)
        end

        next unless d[:verse_text_words].to_i.positive?
        next unless state[:chapter] && state[:verse]

        key = [book, state[:chapter], state[:verse]]
        text = VerseIndex.send(:verse_body_from_stripped, s)
        buf = (verse_buffers[key] ||= +"")
        buf << " " unless buf.empty?
        buf << text
      end

      verse_buffers.each do |(book, chapter, verse), text|
        testament = CorpusStore.testament_for(book)
        emit_text_tokens(block, book, chapter, verse, text, CorpusStore::BUCKET_VERSE_TEXT, testament, 0)
      end
    end

    def self.colophon_event?(event)
      d = event.totals_delta
      return false unless d[:text_words].to_i.positive?

      classification = event.text_words_debug&.dig(:classification)
      classification == :colophon
    end
    private_class_method :colophon_event?

    def self.special_text(text)
      text.to_s.delete_prefix(LineClassifier::IMPORTED_SPECIAL_PREFIX)
    end
    private_class_method :special_text

    def self.emit_line_tokens(block, book, chapter, verse, text, bucket, testament, lineno)
      emit_text_tokens(block, book, chapter, verse, text, bucket, testament, lineno)
    end
    private_class_method :emit_line_tokens

    def self.emit_text_tokens(block, book, chapter, verse, text, bucket, testament, lineno)
      Tokenizer.tokenize(text).each_with_index do |token, i|
        block.call(
          book: book,
          chapter: chapter,
          verse: verse,
          word_index: i + 1,
          token_raw: token,
          bucket: bucket,
          testament: testament,
          lineno: lineno
        )
      end
    end
    private_class_method :emit_text_tokens
  end
end
