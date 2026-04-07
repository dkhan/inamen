# frozen_string_literal: true

RSpec.describe Inamen::CountingService, "#total_for_lines" do
  it "matches full KJV totals (7^7)" do
    kjv_path = File.expand_path("../../data/KJV.txt", __dir__)
    lines = File.readlines(kjv_path, chomp: true)

    totals = described_class.total_for_lines(lines)

    expect(totals[:text_words]).to eq(567)
    expect(totals[:verse_text_words]).to eq(789_629)
    expect(totals[:psalm_heading_words]).to eq(1034)
    expect(totals[:psalm_119_division_words]).to eq(22)
    expect(totals[:chapter_numbers]).to eq(1189)
    expect(totals[:verse_numbers]).to eq(31_102)

    expect(totals[:psalm_chapter_titles] + totals[:numeric_chapter_lines]).to eq(totals[:chapter_numbers])
    expect(totals[:implicit_psalm_verse_1] + totals[:numbered_verse_lines]).to eq(totals[:verse_numbers])

    combined = described_class.combined_total(totals)
    expect(combined).to eq(823_543)
    expect(combined % 7).to eq(0)
  end
end
