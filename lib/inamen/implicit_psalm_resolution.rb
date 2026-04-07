# frozen_string_literal: true

module Inamen
  # Result of resolving a non-numbered line while waiting for Psalm verse 1 (lookahead on next line).
  ImplicitPsalmResolution = Struct.new(
    :clear_waiting,
    :verse_numbers,
    :implicit_psalm_verse_1,
    :verse_text_words,
    :psalm_heading_words,
    keyword_init: true
  ) do
    def [](key)
      to_h[key]
    end

    def to_h
      {
        clear_waiting: clear_waiting,
        verse_numbers: verse_numbers,
        implicit_psalm_verse_1: implicit_psalm_verse_1,
        verse_text_words: verse_text_words,
        psalm_heading_words: psalm_heading_words
      }
    end
  end
end
