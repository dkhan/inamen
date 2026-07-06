# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::CorpusPublisher do
  describe ".prebuilt_path" do
    it "names corpora by edition, checksum, and indexer revision" do
      text_path = Inamen::KjvEditions::EDITIONS["kjv_normalized"]
      path = described_class.prebuilt_path("kjv_normalized", text_path: text_path)

      expect(path).to include("/data/corpora/kjv_normalized-")
      expect(path).to end_with("-#{Inamen::CorpusStore::INDEXER_REVISION}.sqlite")
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
