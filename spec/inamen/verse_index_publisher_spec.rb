# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::VerseIndexPublisher do
  let(:text_path) { File.expand_path("../../data/KJV.txt", __dir__) }

  describe ".prebuilt_path" do
    it "names verse indices by edition, checksum, and revision" do
      path = described_class.prebuilt_path("sample", text_path: text_path)

      expect(path).to include("/data/verse_indices/sample-")
      expect(path).to end_with("-#{described_class::VERSE_INDEX_REVISION}.marshal")
    end
  end

  describe ".build_all_prebuilt!" do
    it "builds each supplied edition" do
      edition = Struct.new(:edition_id, :path, :corpus_text_path, :lines).new("sample", text_path, text_path, ["Genesis", "CHAPTER 1", "1 In"])
      expect(described_class).to receive(:build_prebuilt!).with("sample", text_path: edition.corpus_text_path, lines: edition.lines, force: false)
      described_class.build_all_prebuilt!([edition])
    end
  end
end
