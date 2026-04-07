# frozen_string_literal: true

RSpec.describe Inamen::PsalmHeadingWordsDebugReport do
  describe ".collect" do
    it "matches CountingService psalm_heading_words total" do
      lines = [
        "PSALM 11",
        "To the chief Musician, A Psalm of David.",
        "IN the LORD put I my trust: how say ye to my soul, Flee as a bird to your mountain?",
        "2 For, lo, the wicked bend their bow, they make ready their arrow upon the string, that they may privily shoot at the upright in heart."
      ]
      expected = Inamen::CountingService.total_for_lines(lines)[:psalm_heading_words]
      _entries, total = described_class.collect(lines)
      expect(total).to eq(expected)
    end
  end
end
