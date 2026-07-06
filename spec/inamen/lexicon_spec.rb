# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::Lexicon do
  before(:context) do
    Inamen::Lexicon.clear_cache!
    @db = Inamen::KjvFixture.db
  end

  after(:each) do
    Inamen::Lexicon.clear_cache!
  end

  let(:db) { @db }
  let(:selection) { Inamen::SearchSelection.default }

  describe ".for" do
    it "loads aggregated rows for a search selection" do
      lexicon = described_class.for(db, search_selection: selection)
      rows = lexicon.aggregate(group: :norm_raw)
      jesus = rows.find { |row| row[:token_norm] == "jesus" && row[:token_raw] == "Jesus" }

      expect(rows).not_to be_empty
      expect(jesus[:count]).to eq(967)
    end

    it "matches TokenCountQuery aggregate results" do
      lexicon = described_class.for(db, search_selection: selection)
      expect(lexicon.aggregate(group: :norm_raw)).to eq(
        Inamen::TokenCountQuery.send(:aggregate_from_tokens, db, selection, group: :norm_raw)
      )
    end
  end

  describe "#spellings_for_token" do
    it "returns normalized spellings for case-insensitive exact terms" do
      lexicon = described_class.for(db, search_selection: selection)
      spellings = lexicon.spellings_for_token(token: "jesus", case_sensitive: false)

      expect(spellings).to include("Jesus" => 967, "JESUS" => 6)
      expect(spellings).not_to include("Jesus\u{2019}")
    end
  end

  describe "#wildcard_rows" do
    it "matches wildcard patterns in memory" do
      lexicon = described_class.for(db, search_selection: selection)
      rows = lexicon.wildcard_rows("*jesus*", case_sensitive: false)
      total = rows.sum(&:count)

      expect(total).to eq(984)
      expect(rows.map(&:token_raw)).to include("Bar-jesus")
    end
  end
end
