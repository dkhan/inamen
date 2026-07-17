# frozen_string_literal: true

require "tmpdir"
require "tempfile"
require "inamen/bible_text_preprocessor"
require "inamen/corpus_store"
require "inamen/divisible_by_seven_scan"
require "inamen/verse_highlighter"

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
      expect(moses).to eq(829)
      expect(described_class.token_counts_available?(db)).to be(true)
      expect(db.get_first_value("SELECT SUM(count) FROM token_counts").to_i).to eq(790_849)
    end

    it "preserves source order for multi-line imported special sections" do
      source = <<~TEXT
        Бытие
        1
        1 В начале сотворил Бог небо и землю.
        Книга Есфири
        Предисловие
        [Во второй год царствования Артаксеркса сон видел Мардохей.]
        1
        1 И было во дни Артаксеркса.
        Вторая книга Паралипоменон
        36
        23 Кто есть из вас.
        [МОЛИТВА МАНАССИИ, ЦАРЯ ИУДЕЙСКОГО
        Господи Вседержителю, Боже отцев наших.
        Первая книга Ездры
        1
        1 В первый год Кира.
      TEXT

      Tempfile.create(["russian-special", ".txt"]) do |file|
        file.write(source)
        file.close
        lines = Inamen::BibleTextPreprocessor.from_file(file.path).lines

        Dir.mktmpdir do |dir|
          path = File.join(dir, "sample.sqlite")
          described_class.build!(lines, path: path)
          db = described_class.open(path)
          text = Inamen::VerseHighlighter.bucket_text(
            db,
            book: "2 Chronicles",
            chapter: 36,
            bucket: described_class::BUCKET_COLOPHON
          )

          expect(text).to start_with("МОЛИТВА МАНАССИИ ЦАРЯ ИУДЕЙСКОГО Господи Вседержителю")
          esther_preface = Inamen::VerseHighlighter.bucket_text(
            db,
            book: "Esther",
            chapter: 1,
            bucket: described_class::BUCKET_COLOPHON
          )
          expect(esther_preface).to start_with("Предисловие Во второй год царствования")
        ensure
          db&.close
        end
      end
    end

    it "indexes imported chapter summaries before verse one as colophons" do
      source = <<~TEXT
        Бытие
        Глава 1
        Сотворение неба и земли; 26  сотворение человека.
        1 В начале сотворил Бог небо и землю.
      TEXT

      Tempfile.create(["russian-rbs-summary", ".txt"]) do |file|
        file.write(source)
        file.close
        lines = Inamen::BibleTextPreprocessor.from_file(file.path).lines

        Dir.mktmpdir do |dir|
          path = File.join(dir, "sample.sqlite")
          described_class.build!(lines, path: path)
          db = described_class.open(path)
          text = Inamen::VerseHighlighter.bucket_text(
            db,
            book: "Genesis",
            chapter: 1,
            bucket: described_class::BUCKET_COLOPHON
          )

          expect(text).to eq("Сотворение неба и земли 26 сотворение человека")
        ensure
          db&.close
        end
      end
    end
  end

  describe ".normalize_token" do
    it "folds ligatures so ASCII spellings match KJV tokens" do
      expect(described_class.normalize_token("Alph\u00e6us")).to eq("alphaeus")
      expect(described_class.normalize_token("Alphaeus")).to eq("alphaeus")
    end
  end
end
