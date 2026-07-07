# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::VerseIndexPublisher do
  describe ".prebuilt_path" do
    it "names verse indices by edition, checksum, and revision" do
      text_path = Inamen::KjvEditions::EDITIONS["kjv_normalized"]
      path = described_class.prebuilt_path("kjv_normalized", text_path: text_path)

      expect(path).to include("/data/verse_indices/kjv_normalized-")
      expect(path).to end_with("-#{described_class::VERSE_INDEX_REVISION}.marshal")
    end
  end

  describe ".build_all_prebuilt!" do
    it "builds each bundled edition" do
      expect(described_class).to receive(:build_prebuilt!).with("kjv_normalized", force: false)
      expect(described_class).to receive(:build_prebuilt!).with("concord", force: false)
      described_class.build_all_prebuilt!
    end
  end
end
