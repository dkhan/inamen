# frozen_string_literal: true

require "stringio"

RSpec.describe Inamen::KjvcodeAlignment do
  let(:lines) do
    path = File.expand_path("../../data/KJV.txt", __dir__)
    File.readlines(path, chomp: true)
  end

  describe ".the_star_nt_breakdown" do
    it "reports prefix The*|THE* at 929 matching KJPBS reference" do
      rows = described_class.the_star_nt_breakdown(lines)
      prefix_total = 0
      Inamen::VerseIndex.each_verse(lines) do |book, _ch, _v, text|
        next unless Inamen::BibleBoundaryPatterns::NT_BOOK_SET.include?(book)
        Inamen::Tokenizer.tokenize(text).each do |tok|
          prefix_total += 1 if Inamen::BibleBoundaryPatterns.the_star_nt_token?(tok)
        end
      end
      expect(prefix_total).to eq(929)
      expect(prefix_total - 929).to eq(0)
    end
  end

  describe "near-miss patterns" do
    it "documents corpus vs kjvcode gaps on data/KJV.txt" do
      the_amen = Inamen::BibleBoundaryPatterns.the_amen_nt_concealed(lines)
      expect(the_amen[:sum]).to eq(980)
      expect(the_amen[:sum] - 980).to eq(0)

      expect(Inamen::BibleBoundaryPatterns.god_pure_nt(lines)).to eq(1370)

      same = Inamen::BibleBoundaryPatterns.jesus_boundary_same_verse(lines)
      expect(same[:sum]).to eq(2408)
      expect(same[:sum] - 2401).to eq(7)

      first7 = Inamen::BibleBoundaryPatterns.jesus_boundary_first7_nt(lines)
      expect(first7).to eq(537)
      expect(first7 - 539).to eq(-2)
    end
  end

  describe ".report" do
    it "prints alignment summary without error" do
      expect { described_class.report(lines, out: StringIO.new) }.not_to raise_error
    end
  end
end
