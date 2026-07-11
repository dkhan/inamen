# frozen_string_literal: true

require "inamen/verse_match_query"

RSpec.describe Inamen::VerseMatchQuery do
  let(:db) { Inamen::KjvFixture.db }
  let(:selection) { Inamen::SearchSelection.default }

  describe ".scan" do
    it "lists verses for an exact token" do
      terms = [Inamen::TokenQuery::QueryTerm.new(pattern: "six", case_sensitive: false, exclude: false)]
      result = described_class.scan(db, terms: terms, search_selection: selection)

      expect(result.summary.occurrences).to eq(202)
      expect(result.summary.verses).to be > 100
      expect(result.verses.first.book).to eq("Genesis")
    end

    it "lists verses for a wildcard token" do
      nt = Inamen::SearchSelection.from_legacy(scope: :nt, bucket: :default)
      terms = [Inamen::TokenQuery::QueryTerm.new(pattern: "jesus*", case_sensitive: false, exclude: false)]
      result = described_class.scan(db, terms: terms, search_selection: nt)

      expect(result.summary.occurrences).to eq(983)
      expect(result.summary.verses).to eq(942)
      expect(result.verses.map { |row| [row.book, row.chapter, row.verse] }).to include(["Matthew", 1, 1])
    end

    it "lists include-term verses when exclude terms are present" do
      terms = Inamen::TokenQuery.parse_terms("six|exclude\nseven\n")
      result = described_class.scan(db, terms: terms, search_selection: selection)

      expect(result.summary.occurrences).to eq(463)
      expect(result.verses.none? { |row| row.book == "Genesis" && row.chapter == 1 && row.verse == 1 }).to be(true)
    end

    it "counts colophon and superscription occurrences but not as verses" do
      db_path = Inamen::CorpusPublisher.prebuilt_path("kjv_normalized")
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      full_db = Inamen::CorpusStore.open(db_path)
      selection = Inamen::SearchSelection.default
      terms = [Inamen::TokenQuery::QueryTerm.new(pattern: "Paul", case_sensitive: false, exclude: false)]
      result = described_class.scan(full_db, terms: terms, search_selection: selection)

      expect(result.summary.occurrences).to eq(157)
      expect(result.summary.verses).to eq(153)
      expect(result.verses.any? { |row| row.bucket == Inamen::CorpusStore::BUCKET_COLOPHON }).to be(true)
    ensure
      full_db&.close
    end
  end
end
