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
  end
end
