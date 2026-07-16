# frozen_string_literal: true

module Inamen
  # KJV book groupings aligned with King James Pure Bible Search (BibleLayout BBCE_*).
  module BookCategories
    OT = :ot
    NT = :nt
    AP = :apocrypha

    Category = Struct.new(:id, :label, :testament, :books, keyword_init: true)
    Testament = Struct.new(:id, :label, :categories, keyword_init: true)

  class << self
      def all_books
        @all_books ||= BibleBooks::ALL.freeze
      end

      def ot_books
        @ot_books ||= BibleBooks::OT.freeze
      end

      def nt_books
        @nt_books ||= BibleBooks::NT.freeze
      end

      def apocrypha_books
        @apocrypha_books ||= BibleBooks::APOCRYPHA.freeze
      end

      def book_set
        @book_set ||= all_books.to_set
      end

      def categories_for(testament)
        tree.find { |t| t.id == testament }&.categories || []
      end

      def tree
        @tree ||= [
          Testament.new(id: OT, label: "Old Testament", categories: ot_category_defs),
          Testament.new(id: NT, label: "New Testament", categories: nt_category_defs),
          Testament.new(id: AP, label: "Apocrypha", categories: apocrypha_category_defs)
        ].freeze
      end

      def books_for_category(testament, category_id)
        categories_for(testament).find { |c| c.id == category_id.to_sym }&.books || []
      end

      def label_for_books(books)
        normalized = normalize_books(books)
        return nil if normalized.empty?
        return "whole Bible" if same_books?(normalized, all_books)
        return "Old Testament" if same_books?(normalized, ot_books)
        return "New Testament" if same_books?(normalized, nt_books)
        return "Apocrypha" if same_books?(normalized, apocrypha_books)

        exact_category = tree.flat_map(&:categories).find { |category| same_books?(normalized, category.books) }
        return exact_category.label if exact_category

        category_labels = category_labels_for_exact_cover(normalized)
        return category_labels.join(", ") if category_labels.any?

        normalized.join(", ")
      end

      private

      def normalize_books(books)
        Array(books).select { |book| book_set.include?(book) }
                    .uniq
                    .sort_by { |book| all_books.index(book) }
      end

      def same_books?(left, right)
        left.sort == right.sort
      end

      def category_labels_for_exact_cover(books)
        remaining = books.dup
        labels = []
        tree.each do |testament|
          testament.categories.each do |category|
            next unless (category.books - remaining).empty?

            labels << category.label
            remaining -= category.books
          end
        end

        remaining.empty? ? labels : []
      end

      def ot_category_defs
        [
          category(:law, "Law", OT, 0, 5),
          category(:historical, "Historical", OT, 5, 17),
          category(:wisdom_poetic, "Wisdom / Poetic", OT, 17, 22),
          category(:major_prophets, "Major Prophets", OT, 22, 27),
          category(:minor_prophets, "Minor Prophets", OT, 27, 39)
        ].freeze
      end

      def nt_category_defs
        [
          category(:gospels, "Gospels", NT, 39, 43),
          category(:historical, "Historical", NT, 43, 44),
          category(:pauline_epistles, "Pauline Epistles", NT, 44, 58),
          category(:general_epistles, "General Epistles", NT, 58, 65),
          category(:apocalyptic, "Apocalyptic", NT, 65, 66)
        ].freeze
      end

      def apocrypha_category_defs
        [
          Category.new(id: :books, label: "Books", testament: AP, books: apocrypha_books)
        ].freeze
      end

      def category(id, label, testament, from_idx, to_idx)
        Category.new(
          id: id,
          label: label,
          testament: testament,
          books: all_books[from_idx...to_idx].freeze
        )
      end
    end
  end
end
