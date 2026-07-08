# frozen_string_literal: true

require "fileutils"

module Inamen
  # Prebuilt default-scope lexicon rows for fast boot (avoids SQL on every startup).
  module LexiconPublisher
    FORMAT_VERSION = 1

    module_function

    def prebuilt_root
      File.join(KjvEditions::ROOT, "lexicons")
    end

    def prebuilt_path(edition_id, selection: SearchSelection.default)
      checksum = CorpusPublisher.checksum_prefix(KjvEditions::EDITIONS.fetch(edition_id))
      scope = selection.cache_key
      File.join(prebuilt_root, "#{edition_id}-#{checksum}-#{scope}-v#{FORMAT_VERSION}.marshal")
    end

    def build_prebuilt!(edition_id, force: false)
      dest = prebuilt_path(edition_id)
      return dest if File.file?(dest) && !force

      corpus_path = CorpusPublisher.prebuilt_path(edition_id)
      raise ArgumentError, "Corpus not found for #{edition_id}" unless File.file?(corpus_path)

      FileUtils.mkdir_p(prebuilt_root)
      db = CorpusStore.open(corpus_path)
      selection = SearchSelection.default
      lexicon = Lexicon.new(db, selection)
      File.binwrite(dest, Marshal.dump(lexicon.dump))
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
      Lexicon.load_dump(Marshal.load(File.binread(path))) # rubocop:disable Security/MarshalLoad
    end
  end
end
