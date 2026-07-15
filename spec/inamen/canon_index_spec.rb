# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::CanonIndex do
  it "keeps New Testament ordinals for Protestant canon books" do
    expect(described_class.book_number("Matthew")).to eq(40)
    expect(described_class.nt_book_number("Matthew")).to eq(1)
    expect(described_class.chapter_number("Matthew", 1)).to eq(930)
  end

  it "recognizes Apocrypha books without Protestant chapter ordinals" do
    expect(described_class.book_number("Letter of Jeremiah")).to eq(72)
    expect(described_class.nt_book?("Letter of Jeremiah")).to be(false)
    expect(described_class.chapter_number("Letter of Jeremiah", 1)).to be_nil
    expect(described_class.verse_number("Letter of Jeremiah", 1, 1)).to be_nil
  end
end
