# frozen_string_literal: true

RSpec.describe Inamen::SummaryReport do
  let(:lines) do
    path = File.expand_path("../../data/KJV.txt", __dir__)
    File.readlines(path, chomp: true)
  end

  describe ".build" do
    it "matches the public KJV summary figures" do
      s = described_class.build(lines)

      expect(s[:verse_text_words]).to eq(789_629)
      expect(s[:psalm_heading_words]).to eq(1034)
      expect(s[:colophon_words]).to eq(186)
      expect(s[:cover_title_words]).to eq(5)
      expect(s[:book_title_words]).to eq(376)
      expect(s[:total_chapters]).to eq(1189)
      expect(s[:total_verses]).to eq(31_102)
      expect(s[:psalm_119_inscriptions]).to eq(22)
      expect(s[:total]).to eq(823_543)
    end
  end
end
