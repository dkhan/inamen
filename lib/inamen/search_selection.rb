# frozen_string_literal: true

require "digest"

module Inamen
  # Which corpus text to include in a discovery scan (KJPBS "Search Within").
  class SearchSelection
    attr_reader :colophons, :superscriptions, :books

    def initialize(colophons:, superscriptions:, books:)
      @colophons = colophons
      @superscriptions = superscriptions
      @books = normalize_books(books)
      @book_set = @books.to_set
      freeze
    end

    class << self
      def default
        new(
          colophons: true,
          superscriptions: true,
          books: BookCategories.all_books
        )
      end

      def from_params(raw)
        return default if raw.nil? || raw.empty?

        h = raw.each_with_object({}) { |(k, v), acc| acc[k.to_sym] = v }

        if truthy?(h[:submitted])
          if truthy?(h[:all_books]) && !h.key?(:colophons) && !h.key?(:superscriptions)
            return default
          end

          books = truthy?(h[:all_books]) ? BookCategories.all_books : Array(h[:books])
          new(
            colophons: truthy?(h[:colophons]),
            superscriptions: truthy?(h[:superscriptions]),
            books: books
          )
        elsif h[:books].present? || h.key?(:colophons) || h.key?(:superscriptions)
          new(
            colophons: h.key?(:colophons) ? truthy?(h[:colophons]) : true,
            superscriptions: h.key?(:superscriptions) ? truthy?(h[:superscriptions]) : true,
            books: truthy?(h[:all_books]) ? BookCategories.all_books : Array(h[:books])
          )
        else
          default
        end
      end

      def from_legacy(scope:, bucket:)
        books = legacy_books(scope)
        colophons = false
        superscriptions = false

        case bucket.to_sym
        when :default, "default", :scannable, "scannable"
          colophons = true
          superscriptions = true
        when :verse_text, "verse_text"
          # verse text only
        when :psalm_heading, "psalm_heading"
          superscriptions = true
          books = []
        when :colophon, "colophon"
          colophons = true
          books = []
        else
          raise ArgumentError, "Unknown bucket: #{bucket.inspect}"
        end

        new(colophons: colophons, superscriptions: superscriptions, books: books)
      end

      private

      def legacy_books(scope)
        case scope.to_sym
        when :whole_bible, "whole_bible", :whole, "whole"
          BookCategories.all_books
        when :ot, "ot"
          BookCategories.ot_books
        when :nt, "nt"
          BookCategories.nt_books
        else
          book = BookStatsReport::CANON.find { |(name, _, _)| name.casecmp?(scope.to_s) }&.first
          raise ArgumentError, "Unknown scope: #{scope.inspect}" unless book

          [book]
        end
      end

      def truthy?(value)
        value == true || value == "1" || value == "true" || value == "on"
      end
    end

    def default?
      colophons && superscriptions && books.sort == BookCategories.all_books.sort
    end

    def empty?
      !colophons && !superscriptions && books.empty?
    end

    def label
      return "whole Bible" if default?

      parts = []
      parts << "colophons" if colophons
      parts << "superscriptions" if superscriptions
      parts << book_scope_label if books.any?
      parts.join(", ")
    end

    def to_h
      {
        colophons: colophons,
        superscriptions: superscriptions,
        books: books,
        all_books: books.sort == BookCategories.all_books.sort
      }
    end

    def cache_key
      digest = Digest::SHA256.hexdigest(books.sort.join("\0"))[0, 16]
      "c#{colophons ? 1 : 0}s#{superscriptions ? 1 : 0}:#{digest}"
    end

    def matches_token?(token)
      matches_token_fields?(book: token.book, bucket: token.bucket)
    end

    def matches_token_fields?(book:, bucket:)
      case bucket
      when CorpusStore::BUCKET_COLOPHON
        colophons
      when CorpusStore::BUCKET_PSALM_HEADING
        superscriptions
      when CorpusStore::BUCKET_VERSE_TEXT
        @book_set.include?(book)
      else
        false
      end
    end

    def where_clause
      parts = []
      params = []

      if colophons
        parts << "bucket = ?"
        params << CorpusStore::BUCKET_COLOPHON
      end

      if superscriptions
        parts << "bucket = ?"
        params << CorpusStore::BUCKET_PSALM_HEADING
      end

      if books.any?
        placeholders = (["?"] * books.length).join(", ")
        parts << "(bucket = ? AND book IN (#{placeholders}))"
        params << CorpusStore::BUCKET_VERSE_TEXT
        params.concat(books)
      end

      return ["AND 1=0", []] if parts.empty?

      ["AND (#{parts.join(" OR ")})", params]
    end

    private

    def normalize_books(list)
      valid = list.select { |book| BookCategories.book_set.include?(book) }
      valid.uniq.sort_by { |book| BookCategories.all_books.index(book) }
    end

    def book_scope_label
      if books.sort == BookCategories.ot_books.sort
        "Old Testament"
      elsif books.sort == BookCategories.nt_books.sort
        "New Testament"
      elsif books.length == 1
        books.first
      else
        "#{books.length} books"
      end
    end
  end
end
