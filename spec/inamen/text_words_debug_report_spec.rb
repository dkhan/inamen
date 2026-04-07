# frozen_string_literal: true

RSpec.describe Inamen::TextWordsDebugReport do
  describe ".collect" do
    it "agrees with CountingService total text_words on KJV-shaped lines" do
      lines = [
        "HOLY BIBLE",
        "1",
        "1 IN the beginning.",
        "THE PROVERBS.",
        "2",
        "2 Every way of a man is right in his own eyes:"
      ]
      expected = Inamen::CountingService.total_for_lines(lines)[:text_words]
      _entries, _buckets, total = described_class.collect(lines)
      expect(total).to eq(expected)
    end
  end
end
