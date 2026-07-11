# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::TokenQuery do
  before(:context) do
    @db = Inamen::KjvFixture.db
  end

  let(:db) { @db }

  describe ".parse_terms" do
    it "parses multiple lines" do
      terms = described_class.parse_terms("*jesus*\nsix|cs\n")
      expect(terms.map(&:pattern)).to eq(%w[*jesus* six])
      expect(terms.map(&:case_sensitive)).to eq([false, true])
    end

    it "parses pipe-separated phrases on one line with shared case sensitivity" do
      terms = described_class.parse_terms("six|seven|cs\n*jesus*|Jesus Christ\n")
      expect(terms.map(&:pattern)).to eq(["six", "seven", "*jesus*", "Jesus Christ"])
      expect(terms.map(&:case_sensitive)).to eq([true, true, false, false])
    end

    it "rejects empty input" do
      expect { described_class.parse_terms("  \n") }.to raise_error(ArgumentError, /at least one search term/)
      expect { described_class.parse_terms("six|disabled\n") }.to raise_error(ArgumentError, /at least one search term/)
    end

    it "skips disabled phrase lines" do
      terms = described_class.parse_terms("six|disabled\nseven\n")
      expect(terms.map(&:pattern)).to eq(%w[seven])
    end

    it "marks excluded phrase lines" do
      terms = described_class.parse_terms("six|exclude\nseven\n")
      expect(terms.map(&:pattern)).to eq(%w[six seven])
      expect(terms.map(&:exclude)).to eq([true, false])
    end

    it "applies exclude to all pipe-separated terms in a line" do
      terms = described_class.parse_terms("six|seven|exclude\n")
      expect(terms.map(&:pattern)).to eq(%w[six seven])
      expect(terms.map(&:exclude)).to eq([true, true])
    end
  end

  describe ".scan" do
    it "counts exact case-sensitive tokens without matching substrings in compounds" do
      rows = described_class.scan(
        db,
        terms: [described_class::QueryTerm.new(pattern: "six", case_sensitive: true)],
        scope: :whole_bible,
        bucket: :default
      )
      row = rows.first
      expect(row.count).to eq(190)
      expect(row.spellings).to eq("six" => 190)
    end

    it "counts wildcard jesus patterns across spellings and compounds" do
      rows = described_class.scan(
        db,
        terms: [described_class::QueryTerm.new(pattern: "*jesus*", case_sensitive: false)],
        scope: :whole_bible,
        bucket: :default
      )
      row = rows.first
      expect(row.count).to eq(984)
      expect(row.spellings.keys).to include("Jesus", "JESUS", "Bar-jesus", "Jesus\u{2019}")
      expect(row.spellings.keys).not_to include("Ephesus")
    end

    it "counts jesus* including possessive forms" do
      rows = described_class.scan(
        db,
        terms: [described_class::QueryTerm.new(pattern: "jesus*", case_sensitive: false)],
        scope: :whole_bible,
        bucket: :default
      )
      row = rows.first
      expect(row.count).to eq(983)
      expect(row.spellings.keys).to include("Jesus", "Jesus\u{2019}")
    end

    it "separates jesus from possessive jesus'" do
      rows = described_class.scan(
        db,
        terms: [
          described_class::QueryTerm.new(pattern: "jesus", case_sensitive: false),
          described_class::QueryTerm.new(pattern: "jesus'", case_sensitive: false)
        ],
        scope: :whole_bible,
        bucket: :default
      )
      plain, possessive = rows
      expect(plain.count).to eq(973)
      expect(plain.spellings.keys).not_to include("Jesus\u{2019}")
      expect(possessive.count).to eq(10)
      expect(possessive.spellings).to eq("Jesus\u{2019}" => 10)
    end

    it "counts *jesus' the same as exact jesus'" do
      rows = described_class.scan(
        db,
        terms: [described_class::QueryTerm.new(pattern: "*jesus'", case_sensitive: false)],
        scope: :whole_bible,
        bucket: :default
      )
      row = rows.first
      expect(row.count).to eq(10)
      expect(row.spellings).to eq("Jesus\u{2019}" => 10)
    end

    it "counts consecutive-word phrases" do
      rows = described_class.scan(
        db,
        terms: [described_class::QueryTerm.new(pattern: "Jesus Christ", case_sensitive: false)],
        scope: :whole_bible,
        bucket: :default
      )
      row = rows.first
      expect(row.count).to eq(196)
      expect(row.wildcard).to be(false)
      expect(row.spellings).to eq("Jesus Christ" => 196)
    end

    it "counts phrases with wildcards in words" do
      rows = described_class.scan(
        db,
        terms: [described_class::QueryTerm.new(pattern: "Jesus Chris*", case_sensitive: false)],
        scope: :whole_bible,
        bucket: :default
      )
      row = rows.first
      expect(row.count).to eq(196)
      expect(row.spellings).to eq("Jesus Christ" => 196)
    end

    it "counts pipe-separated terms from one input line" do
      rows = described_class.scan(
        db,
        terms: described_class.parse_terms("six|seven\n"),
        scope: :whole_bible,
        bucket: :default
      )
      expect(rows.map(&:pattern)).to eq(%w[six seven])
      expect(rows.map(&:count)).to eq([202, 463])
    end

    it "subtracts excluded terms in scan results" do
      rows = described_class.scan(
        db,
        terms: described_class.parse_terms("seven\nsix|exclude\n"),
        scope: :whole_bible,
        bucket: :default
      )
      included, excluded = rows
      expect(included.pattern).to eq("seven")
      expect(excluded.pattern).to eq("six")
      expect(excluded.exclude).to be(true)
      expect(rows.sum { |row| row.exclude ? -row.count : row.count }).to eq(463 - 202)
    end

    it "returns independent counts for multiple terms" do
      terms = described_class.parse_terms("seven\ncities")
      rows = described_class.scan(db, terms: terms, scope: :whole_bible, bucket: :default)
      expect(rows.map(&:pattern)).to eq(%w[seven cities])
      expect(rows.map(&:count)).to all(be_positive)
    end

    it "does not split fishermen antimention exclude rows into hundreds of terms" do
      phrase = "ANTIMENTIONS OF JOHN (THE APOSTLE, SON OF ZEBEDEE) | John the Baptist | John was cast"
      terms = described_class.parse_terms("#{phrase}|exclude\n")
      expect(terms.length).to eq(1)
      expect(terms.first.pattern).to eq(phrase)
      expect(terms.first.exclude).to be(true)
    end

    it "counts bulk jesus antimention exclude rows as the sum of phrase parts" do
      db_path = Inamen::CorpusPublisher.prebuilt_path("kjv_normalized")
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      full_db = Inamen::CorpusStore.open(db_path)
      selection = Inamen::SearchSelection.default
      phrase = Inamen::JesusMentionsAntimentions.exclude_phrase
      terms = described_class.parse_terms("#{phrase}|cs|exclude\n")
      rows = described_class.scan(full_db, terms: terms, search_selection: selection)

      expect(rows.length).to eq(1)
      expect(rows.first.count).to eq(3)
    ensure
      full_db&.close
    end

    it "totals 980 for jesus includes minus antimention exclude" do
      db_path = Inamen::CorpusPublisher.prebuilt_path("kjv_normalized")
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      full_db = Inamen::CorpusStore.open(db_path)
      selection = Inamen::SearchSelection.default
      possessive = Inamen::FeatureDiscoverPresets::JESUS_POSSESSIVE
      query = [
        "Jesus|JESUS|#{possessive}|cs",
        "#{Inamen::JesusMentionsAntimentions.exclude_phrase}|cs|exclude"
      ].join("\n")
      rows = described_class.scan(full_db, terms: described_class.parse_terms(query), search_selection: selection)
      total = rows.sum { |row| row.exclude ? -row.count : row.count }

      expect(total).to eq(980)
    ensure
      full_db&.close
    end

    it "matches lexicon counts when using the word-stream fast path" do
      stream = Inamen::WordStreamIndex.build_from_db(db)
      selection = Inamen::SearchSelection.default
      terms = described_class.parse_terms("seven\n*jesus*\nJesus Christ\n")
      lexicon_rows = described_class.scan(db, terms: terms, search_selection: selection)
      stream_rows = described_class.scan(db, terms: terms, search_selection: selection, word_stream: stream)

      expect(stream_rows.map(&:pattern)).to eq(lexicon_rows.map(&:pattern))
      expect(stream_rows.map(&:count)).to eq(lexicon_rows.map(&:count))
      expect(stream_rows.map(&:spellings)).to eq(lexicon_rows.map(&:spellings))
    end
  end
end
