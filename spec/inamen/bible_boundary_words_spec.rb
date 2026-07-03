# frozen_string_literal: true

require "tmpdir"
require "inamen/corpus_store"

RSpec.describe Inamen::BibleBoundaryWords do
  let(:lines) do
    path = File.expand_path("../../data/KJV.txt", __dir__)
    File.readlines(path, chomp: true)
  end

  describe ".anchor_tokens" do
    it "reads Genesis 1:1 and Revelation 22:21 boundary tokens from KJV verse text" do
      anchors = described_class.anchor_tokens(lines)
      expect(anchors[:genesis_first]).to eq("IN")
      expect(anchors[:genesis_last]).to eq("earth")
      expect(anchors[:revelation_first]).to eq("The")
      expect(anchors[:revelation_last]).to eq("Amen")
    end
  end

  describe ".counts" do
    it "sums scannable In, earth, The, and Amen occurrences to 77,777" do
      counts = described_class.counts(lines)
      expect(counts[:in]).to eq(12_674)
      expect(counts[:earth]).to eq(985)
      expect(counts[:the]).to eq(64_041)
      expect(counts[:amen]).to eq(77)
      expect(counts[:sum]).to eq(77_777)
    end

    context "with corpus db" do
      it "matches line-based counts" do
        Dir.mktmpdir do |dir|
          path = File.join(dir, "kjv.sqlite")
          Inamen::CorpusStore.build!(lines, path: path)
          db = Inamen::CorpusStore.open(path)
          from_lines = described_class.counts(lines)
          from_db = described_class.counts(lines, db: db)
          db.close
          expect(from_db).to eq(from_lines)
        end
      end
    end
  end
end
