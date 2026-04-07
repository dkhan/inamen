# frozen_string_literal: true

RSpec.describe Inamen::Totals do
  describe ".empty / #add_partial! / #to_h" do
    it "starts at zero for all buckets" do
      expect(described_class.empty.to_h.values.uniq).to eq([0])
    end

    it "adds only known numeric keys" do
      t = described_class.empty
      t.add_partial!(text_words: 2, verse_text_words: 1, unknown: 99)
      h = t.to_h
      expect(h[:text_words]).to eq(2)
      expect(h[:verse_text_words]).to eq(1)
      expect(h[:chapter_numbers]).to eq(0)
    end
  end

  describe "#combined_total" do
    it "matches CountingService.combined_total for the same buckets" do
      t = described_class.empty
      t.add_partial!(
        text_words: 1,
        psalm_heading_words: 5,
        psalm_119_division_words: 2,
        verse_text_words: 7,
        chapter_numbers: 1,
        verse_numbers: 2
      )
      h = t.to_h
      expect(t.combined_total).to eq(Inamen::CountingService.combined_total(h))
      expect(t.combined_total).to eq(18)
    end
  end

  describe "derived invariants" do
    it "exposes chapter and verse rollups used by debug output" do
      t = described_class.empty
      t.add_partial!(psalm_chapter_titles: 1, numeric_chapter_lines: 2)
      t.add_partial!(implicit_psalm_verse_1: 3, numbered_verse_lines: 4)
      expect(t.chapters_from_titles_plus_numeric).to eq(3)
      expect(t.verses_from_implicit_plus_numbered).to eq(7)
    end
  end
end
