# frozen_string_literal: true

RSpec.describe Inamen::Features do
  let(:lines) do
    path = File.expand_path("../../data/KJV.txt", __dir__)
    File.readlines(path, chomp: true)
  end

  describe ".catalog" do
    it "lists known pattern features" do
      ids = described_class.catalog.map(&:id)
      expect(ids).to include("combined_total", "peter_verses", "paul_verses", "fishermen_gospels", "jesus_mentions")
    end
  end

  describe ".run" do
    it "matches combined total 7^7" do
      result = described_class.run("combined_total", lines: lines)
      expect(result.count).to eq(823_543)
      expect(result.count).to eq(7**7)
    end

    it "counts 153 verses each for Peter and Paul" do
      peter = described_class.run("peter_verses", lines: lines)
      paul = described_class.run("paul_verses", lines: lines)
      expect(peter.count).to eq(153)
      expect(paul.count).to eq(153)
    end

    it "counts fishermen names in the Gospels as 153" do
      result = described_class.run("fishermen_gospels", lines: lines)
      expect(result.count).to eq(153)
    end

    it "counts Jesus mentions as 980 excluding Joshua and Justus" do
      result = described_class.run("jesus_mentions", lines: lines)
      expect(result.count).to eq(980)
      expect(result.details).to include("raw_scannable=983", "excluded=3")
    end

    context "with corpus db" do
      require "tmpdir"
      require "inamen/corpus_store"

      it "matches line-based Jesus count" do
        Dir.mktmpdir do |dir|
          path = File.join(dir, "kjv.sqlite")
          Inamen::CorpusStore.build!(lines, path: path)
          db = Inamen::CorpusStore.open(path)
          from_lines = described_class.run("jesus_mentions", lines: lines)
          from_db = described_class.run("jesus_mentions", lines: lines, db: db)
          db.close
          expect(from_db.count).to eq(from_lines.count)
          expect(from_db.count).to eq(980)
        end
      end
    end
  end

  describe ".run_all" do
    it "returns every catalog feature with expected counts" do
      results = described_class.run_all(lines: lines)
      expect(results.map(&:id)).to eq(described_class.catalog.map(&:id))
      described_class.catalog.each do |entry|
        result = results.find { |r| r.id == entry.id }
        expect(result.count).to eq(entry.expected_count),
                                "#{entry.id}: got #{result.count}, expected #{entry.expected_count}"
      end
    end
  end
end
