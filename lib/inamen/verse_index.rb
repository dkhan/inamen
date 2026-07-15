# frozen_string_literal: true

module Inamen
  # Verse body text keyed by (book, chapter, verse) from the KjvLineParser event stream.
  module VerseIndex
    @verse_map_cache = {}
    @edition_verse_maps = {}
    @edition_chapter_indices = {}

    def self.each_verse(lines)
      return enum_for(:each_verse, lines) unless block_given?

      chapter_index(lines).each do |book, chapters|
        chapters.each do |chapter, verses|
          verses.each do |verse, text|
            yield book, chapter, verse, text
          end
        end
      end
    end

    def self.each_verse_stream(lines)
      return enum_for(:each_verse_stream, lines) unless block_given?

      labels = BookStatsReport.book_label_at_each_index(lines)
      state = { book: nil, chapter: nil, verse: nil }
      buffers = {}

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
        when KjvParseEvent::KIND_IMPLICIT_CHAPTER_OPENING
          state[:verse] = 1 if d[:implicit_chapter_verse_1].to_i.positive? || d[:verse_numbers].to_i.positive?
        when KjvParseEvent::KIND_SPLIT_VERSE_NUMBER
          state[:verse] = s.to_i
        end

        next unless d[:verse_text_words].to_i.positive?
        next unless state[:book] && state[:chapter] && state[:verse]

        key = [state[:book], state[:chapter], state[:verse]]
        text = verse_body_from_stripped(s)
        buf = (buffers[key] ||= +"")
        buf << " " unless buf.empty?
        buf << text
      end

      buffers.each do |(book, chapter, verse), text|
        yield book, chapter, verse, text
      end
    end

    def self.verse_map(lines)
      @verse_map_cache[lines.__id__] ||= flatten_chapter_index(chapter_index_for_lines(lines))
    end

    def self.verse_map_for(cache_key, lines)
      @edition_verse_maps[cache_key] ||= flatten_chapter_index(
        chapter_index_for(cache_key, lines: lines)
      )
    end

    def self.chapter_index_for(cache_key, lines: nil, prebuilt_path: nil)
      @edition_chapter_indices[cache_key] ||= load_or_build_chapter_index(lines, prebuilt_path)
    end

    def self.chapter_index_for_lines(lines)
      chapter_index_for("lines:#{lines.__id__}", lines: lines)
    end

    def self.chapter_index(lines)
      chapter_index_for_lines(lines)
    end

    def self.load_chapter_index_file(path)
      Marshal.load(File.binread(path)) # rubocop:disable Security/MarshalLoad -- trusted prebuilt artifact
    end

    def self.build_chapter_index(lines)
      index = {}
      each_verse_stream(lines) do |book, chapter, verse, text|
        book_chapters = (index[book] ||= {})
        chapter_verses = (book_chapters[chapter] ||= {})
        chapter_verses[verse] = text
      end
      index
    end

    def self.flatten_chapter_index(chapter_index)
      chapter_index.each_with_object({}) do |(book, chapters), map|
        chapters.each do |chapter, verses|
          verses.each do |verse, text|
            map[[book, chapter, verse]] = text
          end
        end
      end
    end

    def self.chapter_verses_from_index(chapter_index, book:, chapter:)
      chapter_index.dig(book.to_s, Integer(chapter)) || {}
    end

    def self.chapter_verses_from_map(map, book:, chapter:)
      target_book = book.to_s
      target_chapter = Integer(chapter)
      map.each_with_object({}) do |((verse_book, verse_chapter, verse_number), text), verses|
        next unless verse_book == target_book && verse_chapter == target_chapter

        verses[verse_number] = text
      end
    end

    def self.clear_cache!
      @verse_map_cache = {}
      @edition_verse_maps = {}
      @edition_chapter_indices = {}
    end

    def self.verse_text(lines, book:, chapter:, verse:)
      chapter_verses_from_index(chapter_index(lines), book: book, chapter: chapter)[Integer(verse)]
    end

    def self.verse_text_from_index(chapter_index, book:, chapter:, verse:)
      chapter_verses_from_index(chapter_index, book: book, chapter: chapter)[Integer(verse)]
    end

    def self.chapter_verses(lines, book:, chapter:)
      chapter_verses_from_index(chapter_index(lines), book: book, chapter: chapter)
    end

    def self.name_token_indices(text, name_prefix)
      re = /\A#{Regexp.escape(name_prefix)}/i
      Tokenizer.tokenize(text).each_with_index.filter_map { |tok, i| i + 1 if tok.match?(re) }
    end

    def self.load_or_build_chapter_index(lines, prebuilt_path)
      if prebuilt_path && File.file?(prebuilt_path)
        load_chapter_index_file(prebuilt_path)
      else
        raise ArgumentError, "lines are required to build a chapter index" unless lines

        build_chapter_index(lines)
      end
    end
    private_class_method :load_or_build_chapter_index

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
