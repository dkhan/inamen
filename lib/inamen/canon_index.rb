# frozen_string_literal: true

require_relative "book_stats_report"
require_relative "corpus_store"

module Inamen
  # Canonical book/chapter/verse ordinals for match detail stats.
  module CanonIndex
    CANON = BookStatsReport::CANON
    BOOK_INDEX = CANON.each_with_index.to_h { |(name, _, _), index| [name, index + 1] }.freeze
    NT_START = BOOK_INDEX.fetch("Matthew")
    TOTAL_BOOKS = CANON.length
    TOTAL_CHAPTERS = CANON.sum { |(_, chapters, _)| chapters }
    TOTAL_VERSES = CANON.sum { |(_, _, verses)| verses }
    NT_BOOKS = CANON.length - (NT_START - 1)
    NT_CHAPTERS = CANON.drop(NT_START - 1).sum { |(_, chapters, _)| chapters }
    NT_VERSES = CANON.drop(NT_START - 1).sum { |(_, _, verses)| verses }

    class << self
      def book_number(book)
        BOOK_INDEX.fetch(book.to_s)
      end

      def nt_book?(book)
        book_number(book) >= NT_START
      end

      def chapters_before(book)
        index = book_number(book) - 1
        return 0 if index <= 0

        CANON.first(index).sum { |(_, chapters, _)| chapters }
      end

      def verses_before(book, chapter = 1, verse = 1)
        book_idx = book_number(book) - 1
        total = CANON.first(book_idx).sum { |(_, _, verses)| verses }
        return total if chapter <= 1 && verse <= 1

        total + (chapter - 1) + (verse - 1)
      end

      def verse_number_for(db, book, chapter, verse)
        return nil if verse.to_i <= 0

        verse_ordinals_for(db)[[book.to_s, chapter.to_i, verse.to_i]]
      end

      def nt_verse_number_for(db, book, chapter, verse)
        verse_num = verse_number_for(db, book, chapter, verse)
        return nil unless verse_num

        verse_num - nt_first_verse_ordinal(db) + 1
      end

      def verse_ordinals_for(db)
        cache = @verse_ordinals_cache ||= {}
        path = db_path_key(db)
        prebuilt = @prebuilt_ordinals_cache ||= {}
        return prebuilt[path][:ordinals] if prebuilt.key?(path)

        cache[db.object_id] ||= build_verse_ordinals(db)
      end

      def install_prebuilt!(db, ordinals:, nt_first:)
        path = db_path_key(db)
        @prebuilt_ordinals_cache ||= {}
        @prebuilt_ordinals_cache[path] = { ordinals: ordinals, nt_first: nt_first }
        @nt_first_verse_ordinal ||= {}
        @nt_first_verse_ordinal[path] = nt_first
      end

      def build_verse_ordinals(db)
        rows = db.execute(<<~SQL, [CorpusStore::BUCKET_VERSE_TEXT])
          SELECT DISTINCT book, chapter, verse FROM tokens WHERE bucket = ?
        SQL
        sorted = rows.map { |book, chapter, verse| [book, chapter.to_i, verse.to_i] }
          .sort_by { |book, chapter, verse| sort_key(book, chapter, verse) }
        sorted.each_with_index.to_h { |key, index| [key, index + 1] }
      end

      def nt_first_verse_ordinal(db)
        path = db_path_key(db)
        prebuilt = @prebuilt_ordinals_cache ||= {}
        return prebuilt[path][:nt_first] if prebuilt.key?(path)

        cache = @nt_first_verse_ordinal ||= {}
        cache[db.object_id] ||= verse_ordinals_for(db).fetch(["Matthew", 1, 1])
      end

      def db_path_key(db)
        db.respond_to?(:filename) ? db.filename.to_s : db.object_id.to_s
      end

      def chapter_number(book, chapter)
        chapters_before(book) + chapter
      end

      def verse_number(book, chapter, verse)
        verses_before(book, chapter, verse) + 1
      end

      def nt_book_number(book)
        book_number(book) - NT_START + 1
      end

      def nt_chapter_number(book, chapter)
        chapter_number(book, chapter) - chapters_before("Matthew")
      end

      def nt_verse_number(book, chapter, verse)
        verse_number(book, chapter, verse) - verses_before("Matthew") + 1
      end

      def sort_key(book, chapter, verse)
        [book_number(book), chapter, verse]
      end
    end
  end
end
