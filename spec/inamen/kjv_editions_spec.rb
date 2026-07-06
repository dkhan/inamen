# frozen_string_literal: true

require "tmpdir"
require "inamen/corpus_store"
require "inamen/features"

RSpec.describe "KJV editions" do
  Inamen::KjvEditions::EDITIONS.each do |edition_id, path|
    describe edition_id do
      before(:context) do
        @lines = Inamen::KjvEditions.read_lines(path)
        @totals = Inamen::CountingService.total_for_lines(@lines)
      end

      it "parses to the 7⁷ combined total" do
        combined = Inamen::CountingService.combined_total(@totals)
        expect(combined).to eq(823_543)
        expect(combined).to eq(7**7)
        expect(@totals[:chapter_numbers]).to eq(1189)
        expect(@totals[:verse_numbers]).to eq(31_102)
        expect(@totals[:verse_text_words]).to eq(789_629)
      end

      it "builds a scannable corpus" do
        Dir.mktmpdir do |dir|
          db_path = File.join(dir, "#{edition_id}.sqlite")
          Inamen::CorpusStore.build!(@lines, path: db_path)
          db = Inamen::CorpusStore.open(db_path)
          counts = Inamen::CorpusStore.bucket_counts(db)
          db.close

          expect(counts[Inamen::CorpusStore::BUCKET_VERSE_TEXT]).to eq(789_629)
          expect(counts[Inamen::CorpusStore::BUCKET_PSALM_HEADING]).to eq(1034)
          expect(counts[Inamen::CorpusStore::BUCKET_COLOPHON]).to eq(186)
          expect(counts.values.sum).to eq(790_849)
        end
      end

      it "passes every catalog feature" do
        Dir.mktmpdir do |dir|
          db_path = File.join(dir, "#{edition_id}-features.sqlite")
          Inamen::CorpusStore.build!(@lines, path: db_path)
          db = Inamen::CorpusStore.open(db_path)

          results = Inamen::Features.run_all(lines: @lines, db: db, path: path)
          db.close

          expect(results.map(&:id)).to eq(Inamen::Features.catalog.map(&:id))
          Inamen::Features.catalog.each do |entry|
            next unless Inamen::KjvEditions.verify_edition_feature?(edition_id, entry.id)

            result = results.find { |r| r.id == entry.id }
            expected = Inamen::KjvEditions.expected_feature_count(edition_id, entry.id)
            expect(result.count).to eq(expected),
                                    "#{edition_id} #{entry.id}: got #{result.count}, expected #{expected}"
          end
        end
      end

      if edition_id == "concord"
        it "differs from the reference catalog on file_character_total" do
          result = Inamen::Features.run(
            "file_character_total",
            lines: @lines,
            db: nil,
            path: path
          )
          expect(result.count).to eq(4_241_503)
          expect(Inamen::KjvEditions.expected_feature_count(edition_id, "file_character_total")).to eq(4_233_726)
        end

        it "matches the reference catalog on jesus_boundary_same_verse after normalization" do
          result = Inamen::Features.run("jesus_boundary_same_verse", lines: @lines, db: nil, path: path)
          expect(result.count).to eq(2401)
        end
      end
    end
  end
end
