# frozen_string_literal: true

require "spec_helper"
require "fileutils"

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
    it "writes totals and explorer cache matching FileStatsReport" do
      small_lines = ["Genesis", "CHAPTER 1", "1 In 7 days."]
      small_path = File.expand_path("../../tmp/file-stats-publisher-small.txt", __dir__)
      FileUtils.mkdir_p(File.dirname(small_path))
      File.write(small_path, small_lines.join("\n"))

      dest = described_class.build_prebuilt!("sample_small", text_path: small_path, lines: small_lines, force: true)
      result = described_class.load_prebuilt!(dest)

      expect(result.total).to eq(Inamen::FileStatsReport.build(small_lines, text_path: small_path).total)
      expect(result.character_count).to eq(File.read(small_path).length)
      expect(result.rows.map(&:key)).to include(:verse_text_words, :cover_and_titles)
      source_text = File.read(small_path)
      source_tokens = Inamen::Tokenizer.tokenize(source_text)
      expect(result.explorer.root.word_count).to eq(source_tokens.count { |token| !token.match?(/\A[0-9]+\z/) })
      expect(result.explorer.root.number_count).to eq(source_tokens.count { |token| token.match?(/\A[0-9]+\z/) })
      expect(result.explorer.root.character_count).to eq(source_text.length)
    ensure
      FileUtils.rm_f(small_path) if small_path
      FileUtils.rm_rf(Inamen::FileStatsExplorer.cache_dir("sample_small"))
      FileUtils.rm_f(dest) if defined?(dest) && dest
    end
  end

  describe ".load_for" do
    it "returns nil when prebuilt file is missing" do
      allow(described_class).to receive(:prebuilt_path).and_return("/tmp/missing-file-stats.marshal")
      expect(described_class.load_for("sample", text_path: text_path)).to be_nil
    end
  end
end
