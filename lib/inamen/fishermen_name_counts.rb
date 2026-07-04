# frozen_string_literal: true

require "set"

module Inamen
  # NT name-mention counts for the John 21 fishing party (Peter, Thomas, Nathanael,
  # James son of Zebedee, John apostle son of Zebedee).
  #
  # James and John use explicit (book, chapter, verse, 1-based word index) whitelists:
  # only those token positions count; every other James*/John* mention in the NT is excluded.
  module FishermenNameCounts
    NT_BOOKS = BookStatsReport::CANON.drop(39).map(&:first).freeze
    GOSPEL_BOOKS = %w[Matthew Mark Luke John].freeze

    # Gospel parallels: James son of Zebedee (19 token occurrences).
    JAMES_SON_OF_ZEBEDEE = {
      ["Matthew", 4, 21] => [11],
      ["Matthew", 10, 2] => [21],
      ["Matthew", 17, 1] => [8],
      ["Mark", 1, 19] => [12],
      ["Mark", 1, 29] => [21],
      ["Mark", 3, 17] => [2, 12],
      ["Mark", 5, 37] => [12, 18],
      ["Mark", 9, 2] => [11],
      ["Mark", 10, 35] => [2],
      ["Mark", 10, 41] => [14],
      ["Mark", 13, 3] => [16],
      ["Mark", 14, 33] => [8],
      ["Luke", 5, 10] => [5],
      ["Luke", 6, 14] => [11],
      ["Luke", 8, 51] => [18],
      ["Luke", 9, 28] => [19],
      ["Luke", 9, 54] => [5]
    }.freeze

    # Gospel parallels plus Luke 22:8 (20 token occurrences).
    JOHN_APOSTLE_SON_OF_ZEBEDEE = {
      ["Matthew", 4, 21] => [17],
      ["Matthew", 10, 2] => [27],
      ["Matthew", 17, 1] => [10],
      ["Mark", 1, 19] => [18],
      ["Mark", 1, 29] => [23],
      ["Mark", 3, 17] => [8],
      ["Mark", 5, 37] => [14],
      ["Mark", 9, 2] => [13],
      ["Mark", 9, 38] => [2],
      ["Mark", 10, 35] => [4],
      ["Mark", 10, 41] => [16],
      ["Mark", 13, 3] => [18],
      ["Mark", 14, 33] => [10],
      ["Luke", 5, 10] => [7],
      ["Luke", 6, 14] => [13],
      ["Luke", 8, 51] => [20],
      ["Luke", 9, 28] => [17],
      ["Luke", 9, 49] => [2],
      ["Luke", 9, 54] => [7],
      ["Luke", 22, 8] => [6]
    }.freeze

    PREFIX_NAMES = {
      peter: "Peter",
      thomas: "Thomas",
      nathanael: "Nathanael"
    }.freeze

    def self.counts(lines, scope: :nt)
      both = counts_both(lines)
      case scope
      when :nt then both[:nt]
      when :gospels then both[:gospels]
      else
        raise ArgumentError, "Unknown scope: #{scope.inspect} (use :nt or :gospels)"
      end
    end

    def self.counts_both(lines)
      @counts_cache ||= {}
      @counts_cache[lines.__id__] ||= compute_counts_both(lines)
    end

    def self.compute_counts_both(lines)
      nt_books = NT_BOOKS.to_set
      gospel_books = GOSPEL_BOOKS.to_set
      nt = PREFIX_NAMES.transform_values { 0 }.merge(james: 0, john: 0)
      gospels = PREFIX_NAMES.transform_values { 0 }.merge(james: 0, john: 0)

      VerseIndex.each_verse(lines) do |book, _chapter, _verse, text|
        PREFIX_NAMES.each do |key, prefix|
          n = prefix_match_count(text, prefix)
          nt[key] += n if nt_books.include?(book)
          gospels[key] += n if gospel_books.include?(book)
        end
      end

      nt[:james] = whitelist_count(JAMES_SON_OF_ZEBEDEE, nt_books)
      nt[:john] = whitelist_count(JOHN_APOSTLE_SON_OF_ZEBEDEE, nt_books)
      gospels[:james] = whitelist_count(JAMES_SON_OF_ZEBEDEE, gospel_books)
      gospels[:john] = whitelist_count(JOHN_APOSTLE_SON_OF_ZEBEDEE, gospel_books)
      nt[:sum] = nt.values_at(:peter, :thomas, :nathanael, :james, :john).sum
      gospels[:sum] = gospels.values_at(:peter, :thomas, :nathanael, :james, :john).sum
      { nt: nt, gospels: gospels }
    end
    private_class_method :compute_counts_both

    def self.scope_books(scope)
      case scope
      when :nt then NT_BOOKS.to_set
      when :gospels then GOSPEL_BOOKS.to_set
      else
        raise ArgumentError, "Unknown scope: #{scope.inspect} (use :nt or :gospels)"
      end
    end

    def self.whitelist_count(whitelist, books)
      whitelist.sum do |(book, _chapter, _verse), indices|
        books.include?(book) ? indices.length : 0
      end
    end
    private_class_method :whitelist_count

    def self.whitelist_matches?(whitelist, lines, name:, texts: nil)
      texts ||= VerseIndex.verse_map(lines)
      whitelist.all? do |ref, expected_indices|
        book, chapter, verse = ref
        text = texts[[book, chapter, verse]]
        return false if text.nil?

        actual = VerseIndex.name_token_indices(text, name)
        actual == expected_indices
      end
    end

    def self.prefix_match_count(text, prefix)
      re = /\A#{Regexp.escape(prefix)}/i
      Tokenizer.tokenize(text).count { |tok| tok.match?(re) }
    end
    private_class_method :prefix_match_count
  end
end
