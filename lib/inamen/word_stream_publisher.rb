# frozen_string_literal: true

require "digest"
require "fileutils"

module Inamen
  # Builds and resolves prebuilt in-memory word-stream indexes for fast discovery search.
  module WordStreamPublisher
    module_function

    def prebuilt_root
      File.join(KjvEditions::ROOT, "word_streams")
    end

    def index_filename(edition_id, checksum_prefix)
      "#{edition_id}-#{checksum_prefix}-#{CorpusStore::INDEXER_REVISION}-ws#{WordStreamIndex::FORMAT_VERSION}.marshal"
    end

    def prebuilt_path(edition_id, text_path: nil)
      text_path ||= KjvEditions::EDITIONS.fetch(edition_id)
      File.join(prebuilt_root, index_filename(edition_id, CorpusPublisher.checksum_prefix(text_path)))
    end

    def prebuilt_available?(edition_id)
      File.file?(prebuilt_path(edition_id))
    end

    def build_prebuilt!(edition_id, corpus_path: nil, force: false)
      dest = prebuilt_path(edition_id)
      return dest if File.file?(dest) && !force

      corpus_path ||= CorpusPublisher.prebuilt_path(edition_id)
      raise ArgumentError, "Corpus not found for #{edition_id}: #{corpus_path}" unless File.file?(corpus_path)

      FileUtils.mkdir_p(prebuilt_root)
      db = CorpusStore.open(corpus_path)
      begin
        index = WordStreamIndex.build_from_db(db)
        File.binwrite(dest, Marshal.dump(index.dump))
      ensure
        db.close
      end
      dest
    end

    def build_all_prebuilt!(force: false)
      KjvEditions::EDITIONS.keys.map do |edition_id|
        corpus_path = CorpusPublisher.prebuilt_path(edition_id)
        CorpusPublisher.build_prebuilt!(edition_id, force: force) unless File.file?(corpus_path) && !force
        build_prebuilt!(edition_id, corpus_path: corpus_path, force: force)
      end
    end

    def load_prebuilt!(path)
      WordStreamIndex.load_dump(Marshal.load(File.binread(path))) # rubocop:disable Security/MarshalLoad
    end
  end
end
