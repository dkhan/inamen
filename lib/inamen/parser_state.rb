# frozen_string_literal: true

module Inamen
  # Mutable flags for the KJV line state machine (Psalm wait, split verse, last non-empty line).
  class ParserState
    attr_accessor :expecting_implicit_psalm_verse_1, :expecting_implicit_verse_1_after_chapter,
                  :expecting_split_verse_body, :prev_nonempty_stripped, :current_book

    def initialize
      @expecting_implicit_psalm_verse_1 = false
      @expecting_implicit_verse_1_after_chapter = false
      @expecting_split_verse_body = false
      @prev_nonempty_stripped = nil
      @current_book = nil
    end

    def in_psalms?
      current_book == "Psalms"
    end
  end
end
