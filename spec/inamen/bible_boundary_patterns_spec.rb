# frozen_string_literal: true

RSpec.describe Inamen::BibleBoundaryPatterns do
  before(:context) do
    @lines = Inamen::KjvFixture.lines
    @db = Inamen::KjvFixture.db
    @boundary = described_class.boundary_word_counts(@lines, db: @db)
    @amen = described_class.amen_count(@lines, db: @db)
    @anchor = described_class.anchor_verse_mentions(@lines)
    @seven = described_class.seven_form_counts(@lines, db: @db)
    @in_amen = described_class.in_amen_genesis_revelation(@lines, db: @db)
    @the_amen = described_class.the_amen_nt_concealed(@lines)
    @god_jesus = described_class.god_jesus_genesis_revelation(@lines, db: @db)
    @first_last = described_class.first_last_chapter_word_count(@lines)
    @ot_first_last = described_class.ot_first_last_chapter_word_count(@lines)
    @god_pure = described_class.god_pure_nt(@lines)
    @beginning = described_class.beginning_end_amen(@lines, db: @db)
    @jesus_tallies = described_class.send(:jesus_boundary_tallies, @lines)
    @jesus_same = @jesus_tallies[:same_verse]
    @jesus_first7 = @jesus_tallies[:first7_nt]
  end

  let(:lines) { @lines }

  describe ".boundary_word_counts" do
    it "sums the four boundary words to 77,777" do
      expect(@boundary[:sum]).to eq(77_777)
    end
  end

  describe ".amen_count" do
    it "counts case-sensitive Amen as 77" do
      expect(@amen).to eq(77)
    end
  end

  describe ".anchor_verse_mentions" do
    it "counts 7 boundary tokens in Genesis 1:1 and Revelation 22:21" do
      expect(@anchor).to eq(7)
    end
  end

  describe ".seven_form_counts" do
    it "partitions scannable tokens into seven forms summing to 77,777" do
      expect(@seven[:sum]).to eq(77_777)
      expect(@seven[:in_cap]).to eq(336)
      expect(@seven[:amen]).to eq(77)
    end
  end

  describe ".in_amen_genesis_revelation" do
    it "counts In and Amen in Genesis and Revelation as 777" do
      expect(@in_amen).to eq(777)
    end
  end

  describe ".the_amen_nt_concealed" do
    it "counts The*|THE* and Amen*|AMEN* prefixes in the N.T." do
      expect(@the_amen[:the_star]).to eq(929)
      expect(@the_amen[:amen]).to eq(51)
      expect(@the_amen[:sum]).to eq(980)
    end
  end

  describe ".god_jesus_genesis_revelation" do
    it "counts God and Jesus in Genesis and Revelation as 343" do
      expect(@god_jesus[:sum]).to eq(343)
    end
  end

  describe ".first_last_chapter_word_count" do
    it "counts Genesis 1 and Revelation 22 verse tokens as 1370" do
      expect(@first_last[:genesis]).to eq(797)
      expect(@first_last[:revelation]).to eq(573)
      expect(@first_last[:sum]).to eq(1370)
    end
  end

  describe ".ot_first_last_chapter_word_count" do
    it "counts Genesis 1 and Malachi 4 verse tokens as 980" do
      expect(@ot_first_last[:sum]).to eq(980)
    end
  end

  describe ".god_pure_nt" do
    it "counts capitalized God forms in N.T. verse text" do
      expect(@god_pure).to eq(1370)
    end
  end

  describe ".beginning_end_amen" do
    it "sums beginning, end, and Amen to 490" do
      expect(@beginning[:sum]).to eq(490)
    end
  end

  describe ".jesus_boundary_same_verse" do
    it "totals boundary forms and pure Jesus in shared verses (excl. Joshua/Justus)" do
      expect(@jesus_same[:boundary]).to eq(1658)
      expect(@jesus_same[:jesus]).to eq(743)
      expect(@jesus_same[:sum]).to eq(2401)
    end
  end

  describe ".jesus_boundary_first7_nt" do
    it "counts KJPBS Jesus (excl. possessive Jesus') in boundary verses across Matthew–1 Corinthians" do
      expect(@jesus_first7).to eq(539)
    end
  end

  context "with corpus db" do
    it "matches line-based boundary and seven-form counts" do
      expect(described_class.boundary_word_counts(@lines, db: @db)).to eq(@boundary)
      expect(described_class.seven_form_counts(@lines, db: @db)).to eq(@seven)
      expect(described_class.jesus_boundary_same_verse(@lines, db: @db)).to eq(@jesus_same)
    end
  end
end
