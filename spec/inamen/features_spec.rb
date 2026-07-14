# frozen_string_literal: true

RSpec.describe Inamen::Features do
  let(:lines) { Inamen::KjvFixture.lines }
  let(:db) { Inamen::KjvFixture.db }

  describe ".catalog" do
    it "lists only the two built-in file-stats totals" do
      ids = described_class.catalog.map(&:id)
      expect(ids).to eq(%w[combined_total file_character_total])
    end
  end

  describe ".fetch" do
    it "raises for a removed hard-coded feature" do
      expect { described_class.fetch("peter_verses") }.to raise_error(ArgumentError)
      expect { described_class.fetch("fishermen_gospels") }.to raise_error(ArgumentError)
      expect { described_class.fetch("jesus_mentions") }.to raise_error(ArgumentError)
    end
  end

  describe ".run" do
    it "matches combined total 7^7" do
      result = described_class.run("combined_total", lines: lines)
      expect(result.count).to eq(823_543)
      expect(result.count).to eq(7**7)
    end

    it "counts every UTF-8 code point in the file as 7 × ⌈777.7²⌉" do
      result = described_class.run(
        "file_character_total",
        lines: lines,
        path: Inamen::KjvFixture::KJV_PATH
      )
      expect(result.count).to eq(4_233_726)
      expect(result.count).to eq(7 * (777.7 * 777.7).ceil)
      expect(result.details).to include("codepoints=4233726")
    end

    it "raises for a removed feature" do
      expect { described_class.run("peter_verses", lines: lines) }.to raise_error(ArgumentError)
    end
  end

  describe ".run_all" do
    it "returns only the two built-in features with expected counts" do
      results = described_class.run_all(lines: lines, db: db, path: Inamen::KjvFixture::KJV_PATH)
      expect(results.map(&:id)).to eq(%w[combined_total file_character_total])
      described_class.catalog.each do |entry|
        result = results.find { |r| r.id == entry.id }
        expect(result.count).to eq(entry.expected_count),
                                "#{entry.id}: got #{result.count}, expected #{entry.expected_count}"
      end
    end
  end
end
