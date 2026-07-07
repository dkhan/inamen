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
  end
end
