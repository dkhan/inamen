# frozen_string_literal: true

RSpec.describe Inamen::FishermenNameCounts do
  let(:lines) { Inamen::KjvFixture.lines }
  let(:texts) { Inamen::VerseIndex.verse_map(lines) }

  describe "whitelists" do
    it "matches James son of Zebedee token positions in KJV verse text" do
      expect(
        described_class.whitelist_matches?(described_class::JAMES_SON_OF_ZEBEDEE, lines, name: "James", texts: texts)
      ).to be(true)
    end

    it "matches John apostle son of Zebedee token positions in KJV verse text" do
      expect(
        described_class.whitelist_matches?(described_class::JOHN_APOSTLE_SON_OF_ZEBEDEE, lines, name: "John", texts: texts)
      ).to be(true)
    end
  end

  describe "KJS antimentions" do
    it "matches the gospel whitelist positions for James" do
      expect(
        described_class.kjs_exclusions_match_whitelist?(
          lines,
          name: "James",
          whitelist: described_class::JAMES_SON_OF_ZEBEDEE,
          exclusion_phrases: Inamen::FishermenGospelsKjs.james_exclusions
        )
      ).to be(true)
    end

    it "matches the gospel whitelist positions for John" do
      expect(
        described_class.kjs_exclusions_match_whitelist?(
          lines,
          name: "John",
          whitelist: described_class::JOHN_APOSTLE_SON_OF_ZEBEDEE,
          exclusion_phrases: Inamen::FishermenGospelsKjs.john_exclusions
        )
      ).to be(true)
    end
  end

  describe ".counts" do
    before(:context) do
      @lines = Inamen::KjvFixture.lines
      @nt = described_class.counts(@lines)
      @gospels = described_class.counts(@lines, scope: :gospels)
    end

    it "counts NT fishing-party name mentions with James/John KJS antimentions in Gospels" do
      c = @nt
      expect(c[:peter]).to eq(162)
      expect(c[:thomas]).to eq(12)
      expect(c[:nathanael]).to eq(6)
      expect(c[:james]).to eq(19)
      expect(c[:john]).to eq(20)
      expect(c[:sum]).to eq(219)
    end

    it "counts the same names in Gospels only" do
      c = @gospels
      expect(c[:peter]).to eq(97)
      expect(c[:thomas]).to eq(11)
      expect(c[:nathanael]).to eq(6)
      expect(c[:james]).to eq(19)
      expect(c[:john]).to eq(20)
      expect(c[:sum]).to eq(153)
    end

    it "builds verse results with KJS-adjusted occurrence totals in Gospels" do
      selection = Inamen::SearchSelection.new(
        colophons: false,
        superscriptions: false,
        books: described_class::GOSPEL_BOOKS
      )
      result = described_class.build_verse_result(@lines, scope: :gospels, search_selection: selection)
      expect(result.summary.occurrences).to eq(153)
      expect(result.summary.books).to eq(4)
    end

    it "reports gross John mentions before KJS antimentions in Gospels" do
      gross = described_class.gross_counts(@lines, scope: :gospels)
      net = described_class.counts(@lines, scope: :gospels)
      expect(gross[:john]).to eq(103)
      expect(net[:john]).to eq(20)
      expect(gross[:john] - net[:john]).to eq(83)
    end
  end
end
