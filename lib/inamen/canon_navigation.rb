# frozen_string_literal: true

module Inamen
  # Previous/next chapter references in Protestant canon order.
  module CanonNavigation
    CANON = BookStatsReport::CANON
    BOOK_INDEX = CANON.each_with_index.to_h { |(name, _, _), index| [name, index] }.freeze

    class << self
      def chapter_ref(book, chapter)
        { book: book.to_s, chapter: Integer(chapter) }
      end

      def prev_chapter(book, chapter)
        book_name = book.to_s
        current_chapter = Integer(chapter)
        book_idx = BOOK_INDEX[book_name]
        return nil unless book_idx

        if current_chapter > 1
          return chapter_ref(book_name, current_chapter - 1)
        end

        return nil if book_idx.zero?

        prev_book, prev_chapters, _verses = CANON[book_idx - 1]
        chapter_ref(prev_book, prev_chapters)
      end

      def next_chapter(book, chapter)
        book_name = book.to_s
        current_chapter = Integer(chapter)
        book_idx = BOOK_INDEX[book_name]
        return nil unless book_idx

        max_chapters = CANON[book_idx][1]
        if current_chapter < max_chapters
          return chapter_ref(book_name, current_chapter + 1)
        end

        return nil if book_idx >= CANON.length - 1

        next_book = CANON[book_idx + 1][0]
        chapter_ref(next_book, 1)
      end
    end
  end
end
