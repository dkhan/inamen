# frozen_string_literal: true

module Inamen
  # Mutable bucket totals for KJV parsing; +to_h+ matches CountingService.empty_counts shape.
  class Totals
    KEYS = %i[
      text_words verse_text_words psalm_heading_words psalm_119_division_words
      chapter_numbers verse_numbers psalm_chapter_titles numeric_chapter_lines
      implicit_psalm_verse_1 numbered_verse_lines
    ].freeze

    def self.empty
      new
    end

    def initialize
      @counts = KEYS.to_h { |k| [k, 0] }
    end

    def [](key)
      @counts[key]
    end

    def []=(key, value)
      @counts[key] = value
    end

    # Adds only keys present in +partial+ (typical output of CountingService.counts_for_line).
    def add_partial!(partial)
      partial.each do |k, v|
        next unless v.is_a?(Numeric) && @counts.key?(k)

        @counts[k] += v
      end
      self
    end

    def to_h
      @counts.dup
    end

    def combined_total
      @counts[:text_words] +
        @counts[:psalm_heading_words] +
        @counts[:psalm_119_division_words] +
        @counts[:verse_text_words] +
        @counts[:chapter_numbers] +
        @counts[:verse_numbers]
    end

    def chapters_from_titles_plus_numeric
      @counts[:psalm_chapter_titles] + @counts[:numeric_chapter_lines]
    end

    def verses_from_implicit_plus_numbered
      @counts[:implicit_psalm_verse_1] + @counts[:numbered_verse_lines]
    end
  end
end
