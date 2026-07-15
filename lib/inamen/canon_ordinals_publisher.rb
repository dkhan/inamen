# frozen_string_literal: true

require "fileutils"

module Inamen
  # Prebuilt verse ordinal map for fast match-detail stats at boot.
  module CanonOrdinalsPublisher
    FORMAT_VERSION = 1

    module_function

    def prebuilt_root
      File.expand_path("../../data/canon_ordinals", __dir__)
    end

    def prebuilt_path(edition_id, text_path:)
      checksum = CorpusPublisher.checksum_prefix(text_path)
      File.join(prebuilt_root, "#{edition_id}-#{checksum}-v#{FORMAT_VERSION}.marshal")
    end

    def build_prebuilt!(edition_id, text_path:, corpus_path: nil, force: false)
      dest = prebuilt_path(edition_id, text_path: text_path)
      return dest if File.file?(dest) && !force

      corpus_path ||= CorpusPublisher.prebuilt_path(edition_id, text_path: text_path)
      raise ArgumentError, "Corpus not found for #{edition_id}" unless File.file?(corpus_path)

      FileUtils.mkdir_p(prebuilt_root)
      db = CorpusStore.open(corpus_path)
      ordinals = CanonIndex.build_verse_ordinals(db)
      nt_first = ordinals[["Matthew", 1, 1]]
      File.binwrite(dest, Marshal.dump({ ordinals: ordinals, nt_first: nt_first }))
    ensure
      db&.close
    end

    def build_all_prebuilt!(editions, force: false)
      editions.map do |edition|
        corpus_path = CorpusPublisher.prebuilt_path(edition.edition_id, text_path: edition.corpus_text_path)
        CorpusPublisher.build_prebuilt!(edition.edition_id, text_path: edition.corpus_text_path, lines: edition.lines, force: force) unless File.file?(corpus_path) && !force
        build_prebuilt!(edition.edition_id, text_path: edition.corpus_text_path, corpus_path: corpus_path, force: force)
      end
    end

    def load_prebuilt!(path)
      Marshal.load(File.binread(path)) # rubocop:disable Security/MarshalLoad
    end
  end
end
