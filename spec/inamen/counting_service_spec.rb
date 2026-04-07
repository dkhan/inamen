# frozen_string_literal: true

RSpec.describe Inamen::CountingService do
  describe ".counts_for_line" do
    it "treats a lone number as a chapter marker" do
      expect(described_class.counts_for_line("42")).to eq(
        text_words: 0, chapter_numbers: 1, verse_numbers: 0
      )
    end

    it "counts leading verse number and text separately" do
      expect(described_class.counts_for_line("3 And God said, Let there be light.")).to eq(
        text_words: 7, chapter_numbers: 0, verse_numbers: 1
      )
    end

    it "counts prose lines as text words only" do
      expect(described_class.counts_for_line("And God said, Let there be light.")).to eq(
        text_words: 7, chapter_numbers: 0, verse_numbers: 0
      )
    end

    it "counts an all-caps book title token as one text word" do
      expect(described_class.counts_for_line("GENESIS")).to eq(
        text_words: 1, chapter_numbers: 0, verse_numbers: 0
      )
    end

    it "counts five-word title lines correctly" do
      expect(described_class.counts_for_line("THE FIRST BOOK OF MOSES")).to eq(
        text_words: 5, chapter_numbers: 0, verse_numbers: 0
      )
    end

    it "counts a two-digit verse prefix like a one-digit verse" do
      expect(described_class.counts_for_line("12 And God said, Let there be light.")).to eq(
        text_words: 7, chapter_numbers: 0, verse_numbers: 1
      )
    end
  end

  describe ".combined_total" do
    it "sums the three buckets" do
      counts = { text_words: 7, chapter_numbers: 1, verse_numbers: 1 }
      expect(described_class.combined_total(counts)).to eq(9)
    end
  end

  describe ".labeled_tokens_for_line" do
    it "tags chapter, verse, and text tokens" do
      expect(described_class.labeled_tokens_for_line("2")).to eq([[:chapter_number, "2"]])
      expect(described_class.labeled_tokens_for_line("1 IN the beginning")).to eq(
        [
          [:verse_number, "1"],
          [:text_word, "IN"],
          [:text_word, "the"],
          [:text_word, "beginning"]
        ]
      )
    end
  end
end
