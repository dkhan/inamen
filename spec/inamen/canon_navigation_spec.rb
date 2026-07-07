# frozen_string_literal: true

require "inamen/canon_navigation"

RSpec.describe Inamen::CanonNavigation do
  describe ".prev_chapter" do
    it "returns the previous chapter in the same book" do
      expect(described_class.prev_chapter("Matthew", 2)).to eq(book: "Matthew", chapter: 1)
    end

    it "returns the last chapter of the previous book" do
      expect(described_class.prev_chapter("Matthew", 1)).to eq(book: "Malachi", chapter: 4)
    end

    it "returns nil before Genesis 1" do
      expect(described_class.prev_chapter("Genesis", 1)).to be_nil
    end
  end

  describe ".next_chapter" do
    it "returns the next chapter in the same book" do
      expect(described_class.next_chapter("Matthew", 1)).to eq(book: "Matthew", chapter: 2)
    end

    it "returns the first chapter of the next book" do
      expect(described_class.next_chapter("Malachi", 4)).to eq(book: "Matthew", chapter: 1)
    end

    it "returns nil after Revelation 22" do
      expect(described_class.next_chapter("Revelation", 22)).to be_nil
    end
  end
end
