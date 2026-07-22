# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::FileStatsPublisher do
  let(:text_path) { File.expand_path("../../data/KJV.txt", __dir__) }
  let(:lines) { File.readlines(text_path, chomp: true) }

  describe ".prebuilt_path" do
    it "names file stats by edition, checksum, and revision" do
      path = described_class.prebuilt_path("sample", text_path: text_path)

      expect(path).to include("/data/file_stats/sample-")
      expect(path).to end_with("-#{described_class::FILE_STATS_REVISION}.marshal")
    end
  end

  describe ".build_all_prebuilt!" do
    it "builds each supplied edition" do
      edition = Struct.new(:edition_id, :path, :lines, :source_lines).new(
        "sample",
        text_path,
        ["Genesis", "CHAPTER 1", "1 In"],
        ["raw title", "raw body"]
      )
      expect(described_class).to receive(:build_prebuilt!).with(
        "sample",
        text_path: text_path,
        lines: edition.lines,
        source_lines: edition.source_lines,
        force: false
      )
      described_class.build_all_prebuilt!([edition])
    end
  end

  describe ".build_prebuilt!" do
    it "writes totals matching FileStatsReport" do
      dest = described_class.build_prebuilt!("sample", text_path: text_path, lines: lines, force: true)
      result = described_class.load_prebuilt!(dest)

      expect(result.total).to eq(823_543)
      expect(result.character_count).to eq(4_233_726)
      expect(result.rows.map(&:key)).to include(:verse_text_words, :cover_and_titles)
    end
  end

  describe ".load_for" do
    it "returns nil when prebuilt file is missing" do
      allow(described_class).to receive(:prebuilt_path).and_return("/tmp/missing-file-stats.marshal")
      expect(described_class.load_for("sample", text_path: text_path)).to be_nil
    end
  end
end
