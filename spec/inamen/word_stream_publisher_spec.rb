# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::WordStreamPublisher do
  let(:text_path) { File.expand_path("../../data/KJV.txt", __dir__) }

  describe ".prebuilt_path" do
    it "names word streams by edition, checksum, and indexer revision" do
      path = described_class.prebuilt_path("sample", text_path: text_path)

      expect(path).to include("/data/word_streams/sample-")
      expect(path).to end_with("-#{Inamen::CorpusStore::INDEXER_REVISION}-ws#{Inamen::WordStreamIndex::FORMAT_VERSION}.marshal")
    end
  end
end
