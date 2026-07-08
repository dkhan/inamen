# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::WordStreamIndex do
  let(:db) { Inamen::KjvFixture.db }

  describe ".build_from_db" do
    it "indexes token positions in stream order" do
      index = described_class.build_from_db(db)

      expect(index.size).to be > 700_000
      expect(index.postings_norm["god"]).not_to be_empty
    end
  end

  describe "#verse_groups_for_term" do
    let(:index) { described_class.build_from_db(db) }
    let(:selection) { Inamen::SearchSelection.default }
    let(:term) { Inamen::TokenQuery::QueryTerm.new(pattern: "Jeroboam", case_sensitive: false, exclude: false) }

    it "returns verse groups without SQL" do
      groups = index.verse_groups_for_term(term, selection: selection)

      expect(groups).not_to be_empty
      expect(groups.first).to respond_to(:verse_key)
      expect(groups.first.indices).not_to be_empty
    end
  end

  describe "#phrase_positions" do
    let(:index) { described_class.build_from_db(db) }
    let(:selection) { Inamen::SearchSelection.default }

    it "finds consecutive-word phrase hits" do
      positions = index.phrase_positions("Jesus Christ", case_sensitive: false, selection: selection)

      expect(positions).not_to be_empty
      expect(index.token_at(positions.first).token_norm).to eq("jesus")
      expect(index.token_at(positions.first + 1).token_norm).to eq("christ")
    end
  end
end
