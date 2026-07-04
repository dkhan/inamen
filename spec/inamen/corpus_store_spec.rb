# frozen_string_literal: true

require "tmpdir"
require "inamen/corpus_store"
require "inamen/divisible_by_seven_scan"

RSpec.describe Inamen::CorpusStore do
  let(:full_lines) { Inamen::KjvFixture.lines }

  describe ".build!" do
    it "indexes Matthew sample verses with correct token locations" do
      idx = full_lines.index { |l| l.strip == "ST. MATTHEW." }
      sample = full_lines[idx, 6]

      Dir.mktmpdir do |dir|
        path = File.join(dir, "sample.sqlite")
        described_class.build!(sample, path: path)

        db = described_class.open(path)
        rows = db.execute(<<~SQL, ["Matthew", 1, 1, described_class::BUCKET_VERSE_TEXT])
          SELECT word_index, token_raw FROM tokens
          WHERE book = ? AND chapter = ? AND verse = ? AND bucket = ?
          ORDER BY word_index
        SQL
        db.close

        expect(rows.map(&:last)).to include("Jesus")
        jesus = rows.find { |(_i, tok)| tok == "Jesus" }
        expect(jesus.first).to eq(7)
      end
    end

    it "indexes Psalm superscriptions and colophons" do
      db = Inamen::KjvFixture.db
      counts = described_class.bucket_counts(db)
      moses = Inamen::DivisibleBySevenScan.count_for(db, token: "Moses", exact: true)

      expect(counts[described_class::BUCKET_VERSE_TEXT]).to eq(789_629)
      expect(counts[described_class::BUCKET_PSALM_HEADING]).to eq(1034)
      expect(counts[described_class::BUCKET_COLOPHON]).to eq(186)
      expect(counts.values.sum).to eq(790_849)
      expect(moses).to eq(848)
    end
  end
end
