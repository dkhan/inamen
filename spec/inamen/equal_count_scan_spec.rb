# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::EqualCountScan do
  before(:context) do
    @db = Inamen::KjvFixture.db
  end

  let(:db) { @db }

  describe ".scan" do
    it "returns groups of words that share the same count" do
      groups = described_class.scan(db, min_count: 7, min_group_size: 2)
      expect(groups).not_to be_empty
      expect(groups).to all(satisfy { |g| g.words.size >= 2 })
      expect(groups).to all(satisfy { |g| g.words.map(&:token_norm).uniq.size == g.words.size })
      expect(groups.first.words.map(&:token_norm)).to eq(groups.first.words.map(&:token_norm).sort)
    end

    it "groups spellings that share the same per-form count" do
      groups = described_class.scan(db, min_count: 448, min_group_size: 2, match_by: :spelling)
      group = groups.find { |g| g.count == 448 }
      norms = group.words.map(&:token_norm)
      expect(norms).to include("seven", "cities")
      expect(norms).not_to include("another")
    end

    it "keeps normalized totals separate from per-spelling counts" do
      norm_groups = described_class.scan(db, min_count: 448, min_group_size: 2, match_by: :norm)
      norm_group = norm_groups.find { |g| g.count == 448 }
      expect(norm_group.words.map(&:token_norm)).to include("cities", "another", "sin")
      expect(norm_group.words.map(&:token_norm)).not_to include("seven")
    end
  end
end
