# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::WordStreamPublisher do
  describe ".prebuilt_path" do
    it "names word streams by edition, checksum, and indexer revision" do
      text_path = Inamen::KjvEditions::EDITIONS["kjv_normalized"]
      path = described_class.prebuilt_path("kjv_normalized", text_path: text_path)

      expect(path).to include("/data/word_streams/kjv_normalized-")
      expect(path).to end_with("-#{Inamen::CorpusStore::INDEXER_REVISION}-ws#{Inamen::WordStreamIndex::FORMAT_VERSION}.marshal")
    end
  end
end
