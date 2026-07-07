# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::VerseIndex do
  let(:lines) { Inamen::KjvEditions.lines_for("kjv_normalized") }

  before { described_class.clear_cache! }

  describe ".build_chapter_index" do
    it "indexes verses by book and chapter" do
      index = described_class.build_chapter_index(lines)

      expect(index.dig("Genesis", 1, 1)).to include("In the beginning")
      expect(index.dig("John", 3, 16)).to include("God so loved")
    end
  end

  describe ".chapter_verses_from_index" do
    it "returns only the requested chapter" do
      index = described_class.build_chapter_index(lines)
      verses = described_class.chapter_verses_from_index(index, book: "Genesis", chapter: 1)

      expect(verses.keys).to all(be_a(Integer))
      expect(verses[1]).to include("In the beginning")
      expect(verses.values.length).to be < 50
    end
  end

  describe ".chapter_index_for" do
    it "loads from a prebuilt marshal file when present" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "test.marshal")
        sample = { "Genesis" => { 1 => { 1 => "In the beginning" } } }
        File.binwrite(path, Marshal.dump(sample))

        index = described_class.chapter_index_for("test-key", lines: lines, prebuilt_path: path)

        expect(index).to eq(sample)
      end
    end
  end
end
