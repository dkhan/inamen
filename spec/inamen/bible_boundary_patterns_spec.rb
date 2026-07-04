# frozen_string_literal: true

require "tmpdir"
require "inamen/corpus_store"

RSpec.describe Inamen::BibleBoundaryPatterns do
  let(:lines) do
    path = File.expand_path("../../data/KJV.txt", __dir__)
    File.readlines(path, chomp: true)
  end

  describe ".boundary_word_counts" do
    it "sums the four boundary words to 77,777" do
      counts = described_class.boundary_word_counts(lines)
      expect(counts[:sum]).to eq(77_777)
    end
  end

  describe ".amen_count" do
    it "counts case-sensitive Amen as 77" do
      expect(described_class.amen_count(lines)).to eq(77)
    end
  end

  describe ".anchor_verse_mentions" do
    it "counts 7 boundary tokens in Genesis 1:1 and Revelation 22:21" do
      expect(described_class.anchor_verse_mentions(lines)).to eq(7)
    end
  end

  describe ".seven_form_counts" do
    it "partitions scannable tokens into seven forms summing to 77,777" do
      counts = described_class.seven_form_counts(lines)
      expect(counts[:sum]).to eq(77_777)
      expect(counts[:in_cap]).to eq(336)
      expect(counts[:amen]).to eq(77)
    end
  end

  describe ".in_amen_genesis_revelation" do
    it "counts In and Amen in Genesis and Revelation as 777" do
      expect(described_class.in_amen_genesis_revelation(lines)).to eq(777)
    end
  end

  describe ".the_amen_nt_concealed" do
    it "counts The*|THE* and Amen*|AMEN* prefixes in the N.T." do
      counts = described_class.the_amen_nt_concealed(lines)
      expect(counts[:the_star]).to eq(929)
      expect(counts[:amen]).to eq(51)
      expect(counts[:sum]).to eq(980)
    end
  end

  describe ".god_jesus_genesis_revelation" do
    it "counts God and Jesus in Genesis and Revelation as 343" do
      counts = described_class.god_jesus_genesis_revelation(lines)
      expect(counts[:sum]).to eq(343)
    end
  end

  describe ".first_last_chapter_word_count" do
    it "counts Genesis 1 and Revelation 22 verse tokens as 1370" do
      counts = described_class.first_last_chapter_word_count(lines)
      expect(counts[:genesis]).to eq(797)
      expect(counts[:revelation]).to eq(573)
      expect(counts[:sum]).to eq(1370)
    end
  end

  describe ".ot_first_last_chapter_word_count" do
    it "counts Genesis 1 and Malachi 4 verse tokens as 980" do
      counts = described_class.ot_first_last_chapter_word_count(lines)
      expect(counts[:sum]).to eq(980)
    end
  end

  describe ".god_pure_nt" do
    it "counts capitalized God forms in N.T. verse text" do
      expect(described_class.god_pure_nt(lines)).to eq(1370)
    end
  end

  describe ".beginning_end_amen" do
    it "sums beginning, end, and Amen to 490" do
      counts = described_class.beginning_end_amen(lines)
      expect(counts[:sum]).to eq(490)
    end
  end

  describe ".jesus_boundary_same_verse" do
    it "totals boundary forms and pure Jesus in shared verses (excl. Joshua/Justus)" do
      counts = described_class.jesus_boundary_same_verse(lines)
      expect(counts[:boundary]).to eq(1661)
      expect(counts[:jesus]).to eq(747)
      expect(counts[:sum]).to eq(2408)
    end
  end

  describe ".jesus_boundary_first7_nt" do
    it "counts Jesus in boundary verses across Matthew–1 Corinthians" do
      expect(described_class.jesus_boundary_first7_nt(lines)).to eq(537)
    end
  end

  context "with corpus db" do
    it "matches line-based boundary and seven-form counts" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "kjv.sqlite")
        Inamen::CorpusStore.build!(lines, path: path)
        db = Inamen::CorpusStore.open(path)

        from_lines = described_class.boundary_word_counts(lines)
        from_db = described_class.boundary_word_counts(lines, db: db)
        expect(from_db).to eq(from_lines)

        seven_lines = described_class.seven_form_counts(lines)
        seven_db = described_class.seven_form_counts(lines, db: db)
        expect(seven_db).to eq(seven_lines)

        db.close
      end
    end
  end
end
