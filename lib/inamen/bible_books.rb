# frozen_string_literal: true

module Inamen
  # Canonical Bible book names and loose heading matching for imported plain text.
  module BibleBooks
    PROTESTANT = [
      "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
      "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah",
      "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
      "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah",
      "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew",
      "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians",
      "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy",
      "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter", "1 John",
      "2 John", "3 John", "Jude", "Revelation"
    ].freeze

    APOCRYPHA = [
      "Tobit", "Judith", "Wisdom of Solomon", "Sirach", "Baruch", "Letter of Jeremiah",
      "Prayer of Azariah", "Susanna", "Bel and the Dragon", "1 Maccabees", "2 Maccabees",
      "3 Maccabees", "1 Esdras", "2 Esdras", "Prayer of Manasseh", "Psalm 151"
    ].freeze

    ALL = (PROTESTANT + APOCRYPHA).freeze
    OT = PROTESTANT.first(39).freeze
    NT = PROTESTANT.drop(39).freeze

    EXTRA_ALIASES = {
      "Psalm" => "Psalms",
      "Song of Songs" => "Song of Solomon",
      "Canticles" => "Song of Solomon",
      "Apocalypse" => "Revelation",
      "Ecclesiasticus" => "Sirach",
      "Wisdom" => "Wisdom of Solomon",
      "Epistle of Jeremiah" => "Letter of Jeremiah"
    }.freeze

    class << self
      def canonical_name(name)
        aliases[normalize_heading(name)]
      end

      def heading?(line)
        !!canonical_name(line)
      end

      def aliases
        @aliases ||= begin
          pairs = ALL.flat_map { |book| aliases_for_book(book).map { |aliaz| [normalize_heading(aliaz), book] } }
          index = pairs.to_h
          EXTRA_ALIASES.each do |aliaz, book|
            index[normalize_heading(aliaz)] ||= book
          end
          index.freeze
        end
      end

      def testament_for(book)
        return "OT" if OT.include?(book)
        return "NT" if NT.include?(book)
        return "AP" if APOCRYPHA.include?(book)

        nil
      end

      private

      def aliases_for_book(book)
        words = book.sub(/\A1 /, "First ").sub(/\A2 /, "Second ").sub(/\A3 /, "Third ")
        compact = book.delete(" ")
        [book, compact, words, "The Book of #{book}", "Book of #{book}"]
      end

      def normalize_heading(text)
        text.to_s
            .unicode_normalize(:nfkc)
            .strip
            .sub(/\A(?:the\s+)?(?:book|epistle|gospel)\s+of\s+/i, "")
            .sub(/\A(?:the\s+)?gospel\s+according\s+to\s+/i, "")
            .gsub(/\bst\.?\s+/i, "")
            .gsub(/\bfirst\b/i, "1")
            .gsub(/\bsecond\b/i, "2")
            .gsub(/\bthird\b/i, "3")
            .gsub(/\bfourth\b/i, "4")
            .gsub(/[^[:alnum:]]+/, " ")
            .strip
            .downcase
      end
    end
  end
end
