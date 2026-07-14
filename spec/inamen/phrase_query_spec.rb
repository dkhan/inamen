# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::PhraseQuery do
  before(:context) do
    @db = Inamen::KjvFixture.db
  end

  let(:db) { @db }

  describe ".phrase?" do
    it "detects multi-word patterns" do
      expect(described_class.phrase?("Jesus Christ")).to be(true)
      expect(described_class.phrase?("Jesus Chris*")).to be(true)
      expect(described_class.phrase?("Jesus")).to be(false)
      expect(described_class.phrase?("*jesus*")).to be(false)
    end
  end

  describe ".count" do
    it "counts consecutive Jesus Christ occurrences" do
      count, spellings = described_class.count(
        db,
        pattern: "Jesus Christ",
        search_selection: Inamen::SearchSelection.default,
        case_sensitive: false
      )

      expect(count).to eq(196)
      expect(spellings).to eq("Jesus Christ" => 196)
    end

    it "counts phrases with wildcards in individual words, including possessives" do
      count, spellings = described_class.count(
        db,
        pattern: "Jesus Chris*",
        search_selection: Inamen::SearchSelection.default,
        case_sensitive: false
      )

      expect(count).to eq(198)
      expect(spellings).to eq("Jesus Christ" => 196, "Jesus Christ\u{2019}s" => 2)
    end

    it "does not match separated words in a verse" do
      count, _spellings = described_class.count(
        db,
        pattern: "Christ Jesus",
        search_selection: Inamen::SearchSelection.default,
        case_sensitive: false
      )

      expect(count).to be < 196
      expect(count).to be_positive
    end
  end
end
