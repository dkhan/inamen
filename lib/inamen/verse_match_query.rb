# frozen_string_literal: true

require_relative "canon_index"
require_relative "phrase_query"
require_relative "token_pattern"

module Inamen
  # Enumerate verse-level search hits for discovery word-count scans.
  module VerseMatchQuery
    DISPLAY_LIMIT = 100

    Hit = Struct.new(:book, :chapter, :verse, :bucket, :word_index, :word_count, :search_index, keyword_init: true) do
      def position_key
        [book, chapter, verse, bucket, word_index, word_count]
      end

      def verse_key
        [book, chapter, verse, bucket]
      end

      def highlight_indices
        (word_index...(word_index + word_count)).to_a
      end
    end

    VerseRow = Struct.new(
      :book, :chapter, :verse, :bucket, :occurrence_count, :highlight_indices, :first_hit_index,
      :html_excerpt, :details,
      keyword_init: true
    )

    Summary = Struct.new(:occurrences, :verses, :chapters, :books, :scope_label, keyword_init: true)

    Result = Struct.new(:summary, :verses, :hits, keyword_init: true)

    VerseGroup = Struct.new(:book, :chapter, :verse, :bucket, :indices, keyword_init: true) do
      def verse_key
        [book, chapter, verse, bucket]
      end
    end

    class << self
      def scan(db, terms:, search_selection:, word_stream: nil)
        selection = resolve_selection(search_selection)
        include_terms = Array(terms).reject(&:exclude)
        exclude_terms = Array(terms).select(&:exclude)

        merged = Hash.new { |hash, key| hash[key] = [] }
        include_terms.each do |term|
          groups = if word_stream
            word_stream.verse_groups_for_term(term, selection: selection)
          else
            verse_groups_for_term(db, term, selection)
          end
          groups.each do |group|
            merged[group.verse_key].concat(group.indices)
          end
        end

        apply_exclusions!(db, merged, exclude_terms, selection, word_stream: word_stream)

        verses = build_verse_rows(merged)
        summary = build_summary(verses, selection, occurrences: verses.sum(&:occurrence_count))

        Result.new(summary: summary, verses: verses, hits: [])
      end

      def prepare_display!(edition, result, offset: 0, limit: DISPLAY_LIMIT)
        return result unless result&.verses&.any?

        rows = result.verses[offset, limit] || []
        return result if rows.empty?
        return result if rows.all? { |row| row.html_excerpt.present? }

        db = edition.db
        canon_verse_total = CanonIndex.verse_ordinals_for(db).length

        rows.each_with_index do |row, index|
          row.html_excerpt = VerseHighlighter.render_edition_row(edition, row)
          hit_index = row.first_hit_index || offset + index + 1
          hit = Hit.new(
            book: row.book,
            chapter: row.chapter,
            verse: row.verse,
            bucket: row.bucket,
            word_index: row.highlight_indices.first || 1,
            word_count: 1,
            search_index: hit_index
          )
          row.details = hit_details(
            db,
            hit,
            hit_index: hit_index,
            verse_row: row,
            summary: result.summary,
            canon_verse_total: canon_verse_total
          )
        end

        result
      end

      def format_reference(book, chapter, verse, bucket = Inamen::CorpusStore::BUCKET_VERSE_TEXT)
        case bucket
        when Inamen::CorpusStore::BUCKET_PSALM_HEADING
          "#{book} #{chapter} (sup.)"
        when Inamen::CorpusStore::BUCKET_COLOPHON
          "#{book} #{chapter} (col.)"
        else
          "#{book} #{chapter}:#{verse}"
        end
      end

      def hit_details(db, hit, hit_index:, verse_row:, summary:, canon_verse_total: nil)
        verse_num = CanonIndex.verse_number_for(db, hit.book, hit.chapter, hit.verse)
        details = {
          reference: format_reference(hit.book, hit.chapter, hit.verse, hit.bucket),
          hit_in_verse: hit_index,
          occurrence_in_search: hit.search_index,
          occurrences_in_search: summary.occurrences,
          occurrence_in_verse: verse_row.occurrence_count,
          book_number: CanonIndex.book_number(hit.book),
          total_books: CanonIndex::TOTAL_BOOKS,
          word_index: hit.word_index,
          word_count: hit.word_count,
          scope_label: summary.scope_label
        }

        chapter_num = CanonIndex.chapter_number(hit.book, hit.chapter)
        if chapter_num
          details[:chapter_number] = chapter_num
          details[:total_chapters] = CanonIndex::TOTAL_CHAPTERS
        end

        if verse_num
          details[:verse_number] = verse_num
          details[:total_verses] = canon_verse_total || CanonIndex.verse_ordinals_for(db).length
        end

        if CanonIndex.nt_book?(hit.book)
          details[:nt_book_number] = CanonIndex.nt_book_number(hit.book)
          details[:nt_total_books] = CanonIndex::NT_BOOKS
          details[:nt_chapter_number] = CanonIndex.nt_chapter_number(hit.book, hit.chapter)
          details[:nt_total_chapters] = CanonIndex::NT_CHAPTERS
          nt_verse_num = CanonIndex.nt_verse_number_for(db, hit.book, hit.chapter, hit.verse)
          if nt_verse_num
            details[:nt_verse_number] = nt_verse_num
            details[:nt_total_verses] = CanonIndex::NT_VERSES
          end
        end

        details
      end

      private

      def resolve_selection(search_selection)
        return search_selection if search_selection.is_a?(SearchSelection)

        SearchSelection.default
      end

      def verse_groups_for_term(db, term, selection)
        if PhraseQuery.phrase?(term.pattern)
          phrase_verse_groups(db, term, selection)
        elsif TokenPattern.wildcard?(term.pattern)
          wildcard_verse_groups(db, term, selection)
        else
          exact_verse_groups(db, term, selection)
        end
      end

      def apply_exclusions!(db, merged, exclude_terms, selection, word_stream:)
        return merged if exclude_terms.empty? || merged.empty?

        excluded = Hash.new { |hash, key| hash[key] = Set.new }
        exclude_terms.each do |term|
          groups = if word_stream
            word_stream.verse_groups_for_term(term, selection: selection)
          else
            verse_groups_for_term(db, term, selection)
          end

          groups.each do |group|
            excluded[group.verse_key].merge(group.indices)
          end
        end

        excluded.each do |verse_key, indices|
          next unless merged.key?(verse_key)

          merged[verse_key] = merged[verse_key].reject { |index| indices.include?(index) }
          merged.delete(verse_key) if merged[verse_key].empty?
        end
        merged
      end

      def exact_verse_groups(db, term, selection)
        where_sql, where_params = selection.where_clause
        if term.case_sensitive
          column = "token_raw"
          value = CorpusStore.normalize_apostrophes(term.pattern)
        else
          column = "token_norm"
          value = CorpusStore.normalize_token(term.pattern)
        end

        sql = <<~SQL
          SELECT book, chapter, verse, bucket, GROUP_CONCAT(word_index) AS indices
          FROM tokens
          WHERE #{column} = ? #{where_sql}
          GROUP BY book, chapter, verse, bucket
          ORDER BY book, chapter, verse, bucket
        SQL

        db.execute(sql, [value] + where_params).map do |book, chapter, verse, bucket, indices|
          VerseGroup.new(
            book: book,
            chapter: chapter.to_i,
            verse: verse.to_i,
            bucket: bucket,
            indices: parse_index_list(indices)
          )
        end
      end

      def wildcard_verse_groups(db, term, selection)
        where_sql, where_params = selection.where_clause
        prefilter = TokenPattern.sql_prefilter(term.pattern, case_sensitive: term.case_sensitive)
        return [] if prefilter == :full

        filter_sql, filter_params =
          case prefilter[:op]
          when :like
            ["AND #{prefilter[:column]} LIKE ? ESCAPE '\\'", [prefilter[:value]]]
          when :glob
            ["AND #{prefilter[:column]} GLOB ?", [prefilter[:value]]]
          end

        sql = <<~SQL
          SELECT book, chapter, verse, bucket,
                 GROUP_CONCAT(word_index || char(30) || token_raw || char(30) || token_norm, char(31)) AS packed
          FROM tokens
          WHERE 1=1 #{filter_sql} #{where_sql}
          GROUP BY book, chapter, verse, bucket
          ORDER BY book, chapter, verse, bucket
        SQL

        db.execute(sql, filter_params + where_params).filter_map do |book, chapter, verse, bucket, packed|
          indices = packed.to_s.split("\x1F", -1).filter_map do |entry|
            word_index, token_raw, token_norm = entry.split("\x1E", 3)
            next unless TokenPattern.matches?(
              term.pattern,
              token_raw: token_raw,
              token_norm: token_norm,
              case_sensitive: term.case_sensitive
            )

            word_index.to_i
          end
          next if indices.empty?

          VerseGroup.new(
            book: book,
            chapter: chapter.to_i,
            verse: verse.to_i,
            bucket: bucket,
            indices: indices
          )
        end
      end

      def phrase_verse_groups(db, term, selection)
        grouped = Hash.new { |hash, key| hash[key] = [] }
        PhraseQuery.positions(
          db,
          pattern: term.pattern,
          search_selection: selection,
          case_sensitive: term.case_sensitive
        ).each do |row|
          key = [row[:book], row[:chapter], row[:verse], row[:bucket]]
          (row[:word_index]...(row[:word_index] + row[:word_count])).each do |index|
            grouped[key] << index
          end
        end

        grouped.map do |(book, chapter, verse, bucket), indices|
          VerseGroup.new(book: book, chapter: chapter, verse: verse, bucket: bucket, indices: indices)
        end
      end

      def parse_index_list(raw)
        raw.to_s.split(",").filter_map do |part|
          value = part.to_i
          value.positive? ? value : nil
        end
      end

      def build_verse_rows(merged)
        rows = merged.map do |(book, chapter, verse, bucket), indices|
          sorted = indices.sort
          VerseRow.new(
            book: book,
            chapter: chapter,
            verse: verse,
            bucket: bucket,
            occurrence_count: indices.length,
            highlight_indices: sorted.uniq,
            first_hit_index: nil
          )
        end

        rows.sort_by! { |row| CanonIndex.sort_key(row.book, row.chapter, row.verse) + [row.bucket] }
        occurrence_index = 1
        rows.each do |row|
          row.first_hit_index = occurrence_index
          occurrence_index += row.occurrence_count
        end
        rows
      end

      def build_summary(verse_rows, selection, occurrences:)
        verse_text_rows = verse_rows.select { |row| row.bucket == CorpusStore::BUCKET_VERSE_TEXT }
        books = verse_text_rows.map(&:book).uniq
        chapters = verse_text_rows.map { |row| [row.book, row.chapter] }.uniq

        Summary.new(
          occurrences: occurrences,
          verses: verse_text_rows.length,
          chapters: chapters.length,
          books: books.length,
          scope_label: selection.label
        )
      end
    end
  end
end
