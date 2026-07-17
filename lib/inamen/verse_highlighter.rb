# frozen_string_literal: true

require "set"
require_relative "tokenizer"
require_relative "verse_index"
require_relative "corpus_store"

module Inamen
  # Render verse text with search-hit tokens wrapped for display.
  module VerseHighlighter
    class << self
      def tokens_for_verse(db, book:, chapter:, verse:, bucket:)
        sql = <<~SQL
          SELECT word_index, token_raw
          FROM tokens
          WHERE book = ? AND chapter = ? AND verse = ? AND bucket = ?
          ORDER BY word_index
        SQL
        db.execute(sql, [book, chapter, verse, bucket]).map do |word_index, token_raw|
          { word_index: word_index.to_i, token_raw: token_raw }
        end
      end

      def highlight_tokens(tokens, highlight_indices)
        indices = highlight_indices.to_set
        tokens.map do |token|
          raw = token[:token_raw].to_s
          if indices.include?(token[:word_index])
            %(<mark class="search-hit">#{escape_html(raw)}</mark>)
          else
            escape_html(raw)
          end
        end.join(" ").html_safe
      end

      def highlight_verse(db, book:, chapter:, verse:, bucket:, highlight_indices:)
        tokens = tokens_for_verse(db, book: book, chapter: chapter, verse: verse, bucket: bucket)
        highlight_tokens(tokens, highlight_indices)
      end

      def bucket_text(db, book:, chapter:, verse: 0, bucket:)
        tokens = tokens_for_verse(db, book: book, chapter: chapter, verse: verse, bucket: bucket)
        return nil if tokens.empty?

        tokens.map { |token| token[:token_raw] }.join(" ")
      end

      def highlight_text(text, highlight_indices)
        source = text.to_s
        return escape_html(source) if highlight_indices.nil? || highlight_indices.empty?

        indices = highlight_indices.to_set
        word_index = 0
        cursor = 0
        html = +""

        source.to_enum(:scan, Tokenizer::TOKEN_PATTERN).each do
          match = Regexp.last_match
          raw = match[0]
          word_index += 1
          html << escape_html(source[cursor...match.begin(0)])
          html << if indices.include?(word_index)
            %(<mark class="search-hit">#{escape_html(raw)}</mark>)
          else
            escape_html(raw)
          end
          cursor = match.end(0)
        end

        html << escape_html(source[cursor..])
        safe_html(html)
      end

      def render_row(lines, db, row, edition: nil)
        if edition && row.bucket == CorpusStore::BUCKET_VERSE_TEXT
          return render_edition_row(edition, row)
        end

        if row.bucket == CorpusStore::BUCKET_VERSE_TEXT
          text = VerseIndex.verse_text(lines, book: row.book, chapter: row.chapter, verse: row.verse)
          return "" if text.nil? || text.empty?

          highlight_text(text, row.highlight_indices)
        else
          highlight_verse(
            db,
            book: row.book,
            chapter: row.chapter,
            verse: row.verse,
            bucket: row.bucket,
            highlight_indices: row.highlight_indices
          )
        end
      end

      def render_edition_row(edition, row)
        if row.bucket == CorpusStore::BUCKET_VERSE_TEXT
          text = edition.verse_text(book: row.book, chapter: row.chapter, verse: row.verse)
          return "" if text.nil? || text.empty?

          highlight_text(text, row.highlight_indices)
        else
          highlight_verse(
            edition.db,
            book: row.book,
            chapter: row.chapter,
            verse: row.verse,
            bucket: row.bucket,
            highlight_indices: row.highlight_indices
          )
        end
      end

      private

      def escape_html(text)
        text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub('"', "&quot;")
      end

      def safe_html(text)
        text.respond_to?(:html_safe) ? text.html_safe : text
      end
    end
  end
end
