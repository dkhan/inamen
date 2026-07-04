# frozen_string_literal: true

RSpec.describe Inamen::Features do
  let(:lines) { Inamen::KjvFixture.lines }
  let(:db) { Inamen::KjvFixture.db }

  describe ".catalog" do
    it "lists known pattern features" do
      ids = described_class.catalog.map(&:id)
      expect(ids).to include(
        "combined_total", "peter_verses", "paul_verses", "fishermen_gospels",
        "jesus_mentions", "bible_boundary_words", "amen_77", "boundary_anchor_verses",
        "boundary_seven_forms", "in_amen_genesis_revelation", "the_amen_nt_concealed",
        "god_jesus_genesis_revelation", "first_last_chapter_words",
        "ot_first_last_chapter_words", "god_pure_nt", "beginning_end_amen",
        "jesus_boundary_same_verse", "jesus_boundary_first7_nt"
      )
    end
  end

  describe ".run" do
    before(:context) do
      @lines = Inamen::KjvFixture.lines
      @db = Inamen::KjvFixture.db
      @combined = described_class.run("combined_total", lines: @lines)
      @peter = described_class.run("peter_verses", lines: @lines)
      @paul = described_class.run("paul_verses", lines: @lines)
      @fishermen = described_class.run("fishermen_gospels", lines: @lines)
      @jesus = described_class.run("jesus_mentions", lines: @lines, db: @db)
      @boundary = described_class.run("bible_boundary_words", lines: @lines, db: @db)
    end

    it "matches combined total 7^7" do
      expect(@combined.count).to eq(823_543)
      expect(@combined.count).to eq(7**7)
    end

    it "counts 153 verses each for Peter and Paul" do
      expect(@peter.count).to eq(153)
      expect(@paul.count).to eq(153)
    end

    it "counts fishermen names in the Gospels as 153" do
      expect(@fishermen.count).to eq(153)
    end

    it "counts Jesus mentions as 980 excluding Joshua and Justus" do
      expect(@jesus.count).to eq(980)
      expect(@jesus.details).to include("raw_scannable=983", "excluded=3")
    end

    it "counts Bible boundary words as 77,777" do
      expect(@boundary.count).to eq(77_777)
      expect(@boundary.details).to include("in=12674 (Genesis 1:1 first word)")
      expect(@boundary.details).to include("earth=985 (Genesis 1:1 last word)")
      expect(@boundary.details).to include("the=64041 (Revelation 22:21 first word)")
      expect(@boundary.details).to include("amen=77 (Revelation 22:21 last word)")
    end

    context "with corpus db" do
      it "matches line-based Jesus count" do
        from_db = described_class.run("jesus_mentions", lines: @lines, db: @db)
        expect(from_db.count).to eq(980)
      end
    end
  end

  describe ".run_all" do
    it "returns every catalog feature with expected counts" do
      results = described_class.run_all(lines: lines, db: db)
      expect(results.map(&:id)).to eq(described_class.catalog.map(&:id))
      described_class.catalog.each do |entry|
        result = results.find { |r| r.id == entry.id }
        expect(result.count).to eq(entry.expected_count),
                                "#{entry.id}: got #{result.count}, expected #{entry.expected_count}"
      end
    end
  end
end
