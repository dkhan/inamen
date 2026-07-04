# frozen_string_literal: true

RSpec.describe Inamen::BibleBoundaryWords do
  let(:lines) { Inamen::KjvFixture.lines }
  let(:db) { Inamen::KjvFixture.db }

  before(:context) do
    @lines = Inamen::KjvFixture.lines
    @anchors = described_class.anchor_tokens(@lines)
    @counts = described_class.counts(@lines, db: Inamen::KjvFixture.db)
  end

  describe ".anchor_tokens" do
    it "reads Genesis 1:1 and Revelation 22:21 boundary tokens from KJV verse text" do
      expect(@anchors[:genesis_first]).to eq("In")
      expect(@anchors[:genesis_last]).to eq("earth")
      expect(@anchors[:revelation_first]).to eq("The")
      expect(@anchors[:revelation_last]).to eq("Amen")
    end
  end

  describe ".counts" do
    it "sums scannable In, earth, The, and Amen occurrences to 77,777" do
      expect(@counts[:in]).to eq(12_674)
      expect(@counts[:earth]).to eq(985)
      expect(@counts[:the]).to eq(64_041)
      expect(@counts[:amen]).to eq(77)
      expect(@counts[:sum]).to eq(77_777)
    end

    context "with corpus db" do
      it "matches line-based counts" do
        from_db = described_class.counts(@lines, db: Inamen::KjvFixture.db)
        expect(from_db).to eq(@counts)
      end
    end
  end
end
