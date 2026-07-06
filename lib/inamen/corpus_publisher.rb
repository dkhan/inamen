# frozen_string_literal: true

require "digest"
require "fileutils"

module Inamen
  # Builds and resolves prebuilt SQLite corpora shipped beside bundled plain-text editions.
  module CorpusPublisher
    module_function

    def prebuilt_root
      File.join(KjvEditions::ROOT, "corpora")
    end

    def checksum_prefix(path)
      Digest::SHA256.file(path).hexdigest[0, 16]
    end

    def corpus_filename(edition_id, checksum_prefix)
      "#{edition_id}-#{checksum_prefix}-#{CorpusStore::INDEXER_REVISION}.sqlite"
    end

    def prebuilt_path(edition_id, text_path: nil)
      text_path ||= KjvEditions::EDITIONS.fetch(edition_id)
      File.join(prebuilt_root, corpus_filename(edition_id, checksum_prefix(text_path)))
    end

    def prebuilt_available?(edition_id)
      File.file?(prebuilt_path(edition_id))
    end

    def build_prebuilt!(edition_id, force: false)
      dest = prebuilt_path(edition_id)
      return dest if File.file?(dest) && !force

      FileUtils.mkdir_p(prebuilt_root)
      lines = KjvEditions.lines_for(edition_id)
      CorpusStore.build!(lines, path: dest)
      dest
    end

    def build_all_prebuilt!(force: false)
      KjvEditions::EDITIONS.keys.map { |id| build_prebuilt!(id, force: force) }
    end
  end
end
