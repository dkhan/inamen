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

    it "rejects empty input" do
      expect { described_class.parse_terms("  \n") }.to raise_error(ArgumentError, /at least one search term/)
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

    it "returns independent counts for multiple terms" do
      terms = described_class.parse_terms("seven\ncities")
      rows = described_class.scan(db, terms: terms, scope: :whole_bible, bucket: :default)
      expect(rows.map(&:pattern)).to eq(%w[seven cities])
      expect(rows.map(&:count)).to all(be_positive)
    end
  end
end
