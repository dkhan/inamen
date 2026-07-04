# frozen_string_literal: true

RSpec.describe Inamen::KjvcodeAlignment do
  let(:lines) { Inamen::KjvFixture.lines }

  before(:context) do
    @lines = Inamen::KjvFixture.lines
    @the_amen = Inamen::BibleBoundaryPatterns.the_amen_nt_concealed(@lines)
    @god_pure = Inamen::BibleBoundaryPatterns.god_pure_nt(@lines)
    @jesus = Inamen::BibleBoundaryPatterns.send(:jesus_boundary_tallies, @lines)
    @same = @jesus[:same_verse]
    @first7 = @jesus[:first7_nt]
  end

  describe ".the_star_nt_breakdown" do
    it "reports prefix The*|THE* at 929 matching KJPBS reference" do
      expect(@the_amen[:the_star]).to eq(929)
      expect(@the_amen[:the_star] - 929).to eq(0)
    end
  end

  describe "near-miss patterns" do
    it "documents corpus vs kjvcode gaps on data/KJV.txt" do
      expect(@the_amen[:sum]).to eq(980)
      expect(@the_amen[:sum] - 980).to eq(0)

      expect(@god_pure).to eq(1370)

      expect(@same[:sum]).to eq(2401)
      expect(@same[:sum] - 2401).to eq(0)

      expect(@first7).to eq(539)
      expect(@first7 - 539).to eq(0)
    end
  end
end
