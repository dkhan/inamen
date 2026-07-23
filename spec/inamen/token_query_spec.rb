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

    it "finds case-sensitive ASCII apostrophe tokens through SQL and word-stream paths" do
      db = SQLite3::Database.new(":memory:")
      db.execute_batch(<<~SQL)
        CREATE TABLE tokens (
          book TEXT NOT NULL,
          chapter INTEGER NOT NULL,
          verse INTEGER NOT NULL,
          word_index INTEGER NOT NULL,
          token_raw TEXT NOT NULL,
          token_norm TEXT NOT NULL,
          testament TEXT NOT NULL,
          bucket TEXT NOT NULL,
          lineno INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE token_counts (
          token_norm TEXT NOT NULL,
          token_raw TEXT NOT NULL,
          bucket TEXT NOT NULL,
          testament TEXT NOT NULL,
          book TEXT NOT NULL,
          count INTEGER NOT NULL
        );
      SQL
      db.execute(
        "INSERT INTO tokens (book, chapter, verse, word_index, token_raw, token_norm, testament, bucket) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        ["Genesis", 1, 1, 1, "God's", Inamen::CorpusStore.normalize_token("God's"), "OT", Inamen::CorpusStore::BUCKET_VERSE_TEXT]
      )
      db.execute(
        "INSERT INTO token_counts (token_norm, token_raw, bucket, testament, book, count) VALUES (?, ?, ?, ?, ?, ?)",
        [Inamen::CorpusStore.normalize_token("God's"), "God's", Inamen::CorpusStore::BUCKET_VERSE_TEXT, "OT", "Genesis", 1]
      )

      term = described_class::QueryTerm.new(pattern: "God's", case_sensitive: true)
      sql_row = described_class.scan(db, terms: [term], search_selection: Inamen::SearchSelection.default).first
      stream = Inamen::WordStreamIndex.build_from_db(db)
      stream_row = described_class.scan(db, terms: [term], search_selection: Inamen::SearchSelection.default, word_stream: stream).first

      expect(sql_row.count).to eq(1)
      expect(sql_row.spellings).to eq("God's" => 1)
      expect(stream_row.count).to eq(1)
      expect(stream_row.spellings).to eq("God's" => 1)
    ensure
      db&.close
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

    it "counts phrases with wildcards in words, including possessives" do
      rows = described_class.scan(
        db,
        terms: [described_class::QueryTerm.new(pattern: "Jesus Chris*", case_sensitive: false)],
        scope: :whole_bible,
        bucket: :default
      )
      row = rows.first
      expect(row.count).to eq(198)
      expect(row.spellings).to eq("Jesus Christ" => 196, "Jesus Christ\u{2019}s" => 2)
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
