# frozen_string_literal: true

RSpec.describe Inamen::ChapterReport do
  let(:lines) do
    path = File.expand_path("../../data/KJV.txt", __dir__)
    File.readlines(path, chomp: true)
  end

  describe ".stats_for_chapter" do
    it "reports Genesis 1 with canon verse count and stable totals from the event stream" do
      s = described_class.stats_for_chapter(lines, book: "Genesis", chapter: 1)

      expect(s[:book]).to eq("Genesis")
      expect(s[:chapter]).to eq(1)
      expect(s[:verse_count]).to eq(31)
      expect(s[:verse_text_words]).to eq(797)
      expect(s[:combined]).to eq(829)
      expect(s[:divisible_by_7]).to be false
    end

    # KJV: PSALM 1 then implicit verse 1 body (no PsalmHeading line between title and body).
    it "reports Psalms 1 without a heading before implicit verse 1" do
      s = described_class.stats_for_chapter(lines, book: "Psalms", chapter: 1)

      expect(s[:verse_count]).to eq(7)
      expect(s[:verse_text_words]).to eq(130)
      expect(s[:combined]).to eq(137)
    end

    # KJV: PSALM 3, superscription heading, then implicit verse 1.
    it "reports Psalms 3 with a heading and implicit verse 1" do
      s = described_class.stats_for_chapter(lines, book: "Psalms", chapter: 3)

      expect(s[:verse_count]).to eq(9)
      expect(s[:verse_text_words]).to eq(139)
      expect(s[:combined]).to eq(159)
    end
  end
end
