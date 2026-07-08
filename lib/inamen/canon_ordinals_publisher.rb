# frozen_string_literal: true

require "fileutils"

module Inamen
  # Prebuilt verse ordinal map for fast match-detail stats at boot.
  module CanonOrdinalsPublisher
    FORMAT_VERSION = 1

    module_function

    def prebuilt_root
      File.join(KjvEditions::ROOT, "canon_ordinals")
    end

    def prebuilt_path(edition_id)
      checksum = CorpusPublisher.checksum_prefix(KjvEditions::EDITIONS.fetch(edition_id))
      File.join(prebuilt_root, "#{edition_id}-#{checksum}-v#{FORMAT_VERSION}.marshal")
    end

    def build_prebuilt!(edition_id, force: false)
      dest = prebuilt_path(edition_id)
      return dest if File.file?(dest) && !force

      corpus_path = CorpusPublisher.prebuilt_path(edition_id)
      raise ArgumentError, "Corpus not found for #{edition_id}" unless File.file?(corpus_path)

      FileUtils.mkdir_p(prebuilt_root)
      db = CorpusStore.open(corpus_path)
      ordinals = CanonIndex.build_verse_ordinals(db)
      nt_first = ordinals.fetch(["Matthew", 1, 1])
      File.binwrite(dest, Marshal.dump({ ordinals: ordinals, nt_first: nt_first }))
    ensure
      db&.close
    end

    def build_all_prebuilt!(force: false)
      KjvEditions::EDITIONS.keys.map do |edition_id|
        corpus_path = CorpusPublisher.prebuilt_path(edition_id)
        CorpusPublisher.build_prebuilt!(edition_id, force: force) unless File.file?(corpus_path) && !force
        build_prebuilt!(edition_id, force: force)
      end
    end

    def load_prebuilt!(path)
      Marshal.load(File.binread(path)) # rubocop:disable Security/MarshalLoad
    end
  end
end
