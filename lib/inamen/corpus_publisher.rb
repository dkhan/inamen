# frozen_string_literal: true

require "digest"
require "fileutils"

module Inamen
  # Builds and resolves prebuilt SQLite corpora for edition plain-text files.
  module CorpusPublisher
    module_function

    def prebuilt_root
      File.expand_path("../../data/corpora", __dir__)
    end

    def checksum_prefix(path)
      Digest::SHA256.file(path).hexdigest[0, 16]
    end

    def corpus_filename(edition_id, checksum_prefix)
      "#{edition_id}-#{checksum_prefix}-#{CorpusStore::INDEXER_REVISION}.sqlite"
    end

    def prebuilt_path(edition_id, text_path:)
      File.join(prebuilt_root, corpus_filename(edition_id, checksum_prefix(text_path)))
    end

    def prebuilt_available?(edition_id, text_path:)
      File.file?(prebuilt_path(edition_id, text_path: text_path))
    end

    def build_prebuilt!(edition_id, text_path:, lines: nil, force: false)
      dest = prebuilt_path(edition_id, text_path: text_path)
      return dest if File.file?(dest) && !force

      FileUtils.mkdir_p(prebuilt_root)
      lines ||= File.readlines(text_path, chomp: true)
      CorpusStore.build!(lines, path: dest)
      dest
    end

    def build_all_prebuilt!(editions, force: false)
      editions.map do |edition|
        build_prebuilt!(edition.edition_id, text_path: edition.corpus_text_path, lines: edition.lines, force: force)
      end
    end
  end
end
