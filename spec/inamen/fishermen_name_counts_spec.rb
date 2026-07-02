# frozen_string_literal: true

RSpec.describe Inamen::FishermenNameCounts do
  let(:lines) do
    path = File.expand_path("../../data/KJV.txt", __dir__)
    File.readlines(path, chomp: true)
  end

  describe "whitelists" do
    it "matches James son of Zebedee token positions in KJV verse text" do
      expect(
        described_class.whitelist_matches?(described_class::JAMES_SON_OF_ZEBEDEE, lines, name: "James")
      ).to be(true)
    end

    it "matches John apostle son of Zebedee token positions in KJV verse text" do
      expect(
        described_class.whitelist_matches?(described_class::JOHN_APOSTLE_SON_OF_ZEBEDEE, lines, name: "John")
      ).to be(true)
    end
  end

  describe ".counts" do
    it "counts NT fishing-party name mentions with James/John whitelists" do
      c = described_class.counts(lines)

      expect(c[:peter]).to eq(162)
      expect(c[:thomas]).to eq(12)
      expect(c[:nathanael]).to eq(6)
      expect(c[:james]).to eq(19)
      expect(c[:john]).to eq(20)
      expect(c[:sum]).to eq(219)
    end

    it "counts the same names in Gospels only" do
      c = described_class.counts(lines, scope: :gospels)

      expect(c[:peter]).to eq(97)
      expect(c[:thomas]).to eq(11)
      expect(c[:nathanael]).to eq(6)
      expect(c[:james]).to eq(19)
      expect(c[:john]).to eq(20)
      expect(c[:sum]).to eq(153)
    end
  end
end
