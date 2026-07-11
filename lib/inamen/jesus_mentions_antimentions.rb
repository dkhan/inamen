# frozen_string_literal: true

require_relative "bible_boundary_patterns"

module Inamen
  # KJPBS-style antimention exclude row for Jesus mentions (Joshua / Jesus Justus).
  module JesusMentionsAntimentions
    EXCLUDE_VERSES = BibleBoundaryPatterns::JESUS_NON_CHRIST_VERSES
    EXCLUDE_LABEL = "ANTIMENTIONS OF JESUS (JOSHUA AND JUSTUS)"

    # Distinctive scannable sub-phrases for Acts 7:45, Hebrews 4:8, and Colossians 4:11.
    ANTIMENTION_PARTS = [
      "Which also our fathers that came after brought in with Jesus",
      "For if Jesus had given them rest",
      "And Jesus which is called Justus"
    ].freeze

    class << self
      def exclude_phrase
        @exclude_phrase ||= ([EXCLUDE_LABEL] + ANTIMENTION_PARTS).join(" | ")
      end

      def antimention_parts(phrase)
        parts = split_alternatives(phrase.to_s)
        parts = parts.drop(1) if parts.first&.match?(/\AANTIMENTIONS OF JESUS/i)
        parts
      end

      def reload!
        @exclude_phrase = nil
      end

      private

      def split_alternatives(text)
        TokenPattern.split_phrase_patterns(text)
      rescue ArgumentError
        text.split("|").map(&:strip).reject(&:empty?)
      end
    end
  end
end
