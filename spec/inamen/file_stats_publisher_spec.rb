# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::FileStatsPublisher do
  describe ".prebuilt_path" do
    it "names file stats by edition, checksum, and revision" do
      text_path = Inamen::KjvEditions::EDITIONS["kjv_normalized"]
      path = described_class.prebuilt_path("kjv_normalized", text_path: text_path)

      expect(path).to include("/data/file_stats/kjv_normalized-")
      expect(path).to end_with("-#{described_class::FILE_STATS_REVISION}.marshal")
    end
  end

  describe ".build_all_prebuilt!" do
    it "builds each bundled edition" do
      expect(described_class).to receive(:build_prebuilt!).with("kjv_normalized", force: false)
      expect(described_class).to receive(:build_prebuilt!).with("concord", force: false)
      described_class.build_all_prebuilt!
    end
  end

  describe ".build_prebuilt!" do
    it "writes totals matching FileStatsReport for kjv_normalized" do
      dest = described_class.build_prebuilt!("kjv_normalized", force: true)
      result = described_class.load_prebuilt!(dest)

      expect(result.total).to eq(823_543)
      expect(result.character_count).to eq(4_233_726)
      expect(result.rows.map(&:key)).to include(:verse_text_words, :cover_and_titles)
    end
  end

  describe ".load_for" do
    it "returns nil when prebuilt file is missing" do
      allow(described_class).to receive(:prebuilt_path).and_return("/tmp/missing-file-stats.marshal")
      expect(described_class.load_for("kjv_normalized")).to be_nil
    end
  end
end
