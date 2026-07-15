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
      text_path = File.expand_path("../../data/KJV.txt", __dir__)
      db_path = Inamen::CorpusPublisher.prebuilt_path("sample", text_path: text_path)
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
    it "highlights every word in a multi-word phrase match" do
      text_path = File.expand_path("../../data/KJV.txt", __dir__)
      db_path = Inamen::CorpusPublisher.prebuilt_path("sample", text_path: text_path)
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      full_db = Inamen::CorpusStore.open(db_path)
      selection = Inamen::SearchSelection.default
      phrase = "Which also our fathers that came after brought in with Jesus"
      terms = [Inamen::TokenQuery::QueryTerm.new(pattern: phrase, case_sensitive: false, exclude: false)]
      result = described_class.scan(full_db, terms: terms, search_selection: selection)
      row = result.verses.find { |verse| verse.book == "Acts" && verse.chapter == 7 && verse.verse == 45 }

      expect(row).not_to be_nil
      expect(row.highlight_indices.length).to eq(Inamen::PhraseQuery.phrase_words(phrase).length)
    ensure
      full_db&.close
    end
  end

  describe ".format_reference" do
    it "shortens superscription and colophon labels" do
      expect(described_class.format_reference("Psalms", 3, 0, Inamen::CorpusStore::BUCKET_PSALM_HEADING))
        .to eq("Psalms 3 (sup.)")
      expect(described_class.format_reference("2 Timothy", 4, 0, Inamen::CorpusStore::BUCKET_COLOPHON))
        .to eq("2 Timothy 4 (col.)")
    end
  end
end
