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

    it "matches line-scan totals when using the word-stream fast path" do
      db_path = Inamen::CorpusPublisher.prebuilt_path("kjv_normalized")
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      db = Inamen::CorpusStore.open(db_path)
      stream = Inamen::WordStreamIndex.build_from_db(db)
      exclusions = {
        james_exclusions: Inamen::FishermenGospelsKjs.james_exclusions,
        john_exclusions: Inamen::FishermenGospelsKjs.john_exclusions
      }
      Thread.current[:inamen_fishermen_gospel_scan_cache] = nil
      line_bundle = described_class.gospel_scan_bundle(@lines, **exclusions)
      Thread.current[:inamen_fishermen_gospel_scan_cache] = nil
      stream_bundle = described_class.gospel_scan_bundle(@lines, word_stream: stream, **exclusions)
      verse_line = described_class.build_verse_result(@lines, scope: :gospels)
      verse_stream = described_class.build_verse_result(@lines, scope: :gospels, word_stream: stream)

      expect(stream_bundle.gross).to eq(line_bundle.gross)
      expect(stream_bundle.gross_spellings).to eq(line_bundle.gross_spellings)
      expect(stream_bundle.net).to eq(line_bundle.net)
      expect(verse_stream.summary.occurrences).to eq(verse_line.summary.occurrences)
      expect(verse_stream.summary.verses).to eq(verse_line.summary.verses)
    ensure
      db&.close
      Thread.current[:inamen_fishermen_gospel_scan_cache] = nil
    end
  end
end
