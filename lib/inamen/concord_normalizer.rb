# frozen_string_literal: true

module Inamen
  # Cambridge Concord prints "CHAPTER N" then verse 1 without a number. Some chapter
  # openings use ALL CAPS (IN, JESUS) where kjv_normalized uses In/Jesus for kjvcode
  # boundary features.
  module ConcordNormalizer
    module_function

    def normalize(lines)
      out = []
      expecting_implicit_verse_1 = false

      lines.each do |line|
        stripped = KjvLine.strip(line)
        if stripped.empty?
          out << line
          next
        end

        if stripped.match?(CountingService::CHAPTER_WORD_LINE)
          expecting_implicit_verse_1 = true
          out << line
          next
        end

        if expecting_implicit_verse_1
          expecting_implicit_verse_1 = false
          out << normalize_implicit_verse_opening(line, stripped)
          next
        end

        out << line
      end

      out
    end

    def normalize_implicit_verse_opening(line, stripped)
      normalized = stripped.sub(/\AIN\b/, "In").sub(/\AJESUS\b/, "Jesus")
      return line if normalized == stripped

      leading = line[/\A\s*/] || ""
      leading + normalized
    end
  end
end
