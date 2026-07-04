# frozen_string_literal: true

require_relative "bible_boundary_patterns"

module Inamen
  # Counts anchored on the first/last tokens of Genesis 1:1 and Revelation 22:21.
  #
  # Genesis 1:1 begins with IN and ends with earth; Revelation 22:21 begins with The
  # and ends with Amen. Each anchor word is counted across scannable text (verse body,
  # psalm superscriptions, colophons) with the stated case rules; the four counts sum
  # to 77,777 on the KJV.
  module BibleBoundaryWords
    GENESIS = BibleBoundaryPatterns::GENESIS
    REVELATION = BibleBoundaryPatterns::REVELATION
    RULES = BibleBoundaryPatterns::BOUNDARY_RULES
    EXPECTED_SUM = 77_777

    class << self
      def anchor_tokens(lines)
        BibleBoundaryPatterns.anchor_tokens(lines)
      end

      def counts(lines, db: nil)
        BibleBoundaryPatterns.boundary_word_counts(lines, db: db)
      end
    end
  end
end
