# frozen_string_literal: true

module Inamen
  # A single phrase or token match location in the corpus token stream.
  MatchPosition = Struct.new(:book, :chapter, :verse, :bucket, :word_index, :word_count, keyword_init: true) do
    def key
      [book, chapter, verse, bucket, word_index, word_count]
    end

    def contains?(other)
      book == other.book &&
        chapter == other.chapter &&
        verse == other.verse &&
        bucket == other.bucket &&
        word_index <= other.word_index &&
        word_index + word_count >= other.word_index + other.word_count
    end
  end
end
