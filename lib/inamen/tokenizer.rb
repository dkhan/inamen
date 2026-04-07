# frozen_string_literal: true

module Inamen
  # Splits text into tokens: Unicode letter-words (with internal apostrophe/hyphen),
  # or runs of ASCII digits. Other characters act as separators and are dropped.
  class Tokenizer
    # Letter-words: at least one letter; apostrophe or hyphen only between letter runs.
    # Numbers: digit runs as their own tokens.
    TOKEN_PATTERN = /
      (?:\p{L}\p{M}*)+(?:[-'](?:\p{L}\p{M}*)+)*
      |
      [0-9]+
    /x

    def self.tokenize(string)
      return [] if string.nil?

      s = string.to_s
      return [] if s.empty?

      s.scan(TOKEN_PATTERN)
    end
  end
end
