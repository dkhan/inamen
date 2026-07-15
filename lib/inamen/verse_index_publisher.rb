# frozen_string_literal: true

require "digest"
require "fileutils"

module Inamen
  # Builds and resolves prebuilt chapter-indexed verse maps for editions.
  module VerseIndexPublisher
    VERSE_INDEX_REVISION = "1"

    module_function

    def prebuilt_root
      File.expand_path("../../data/verse_indices", __dir__)
    end

    def index_filename(edition_id, checksum_prefix)
      "#{edition_id}-#{checksum_prefix}-#{VERSE_INDEX_REVISION}.marshal"
    end

    def prebuilt_path(edition_id, text_path:)
      File.join(prebuilt_root, index_filename(edition_id, CorpusPublisher.checksum_prefix(text_path)))
    end

    def prebuilt_available?(edition_id, text_path:)
      File.file?(prebuilt_path(edition_id, text_path: text_path))
    end

    def build_prebuilt!(edition_id, text_path:, lines: nil, force: false)
      dest = prebuilt_path(edition_id, text_path: text_path)
      return dest if File.file?(dest) && !force

      FileUtils.mkdir_p(prebuilt_root)
      lines ||= File.readlines(text_path, chomp: true)
      index = VerseIndex.build_chapter_index(lines)
      File.binwrite(dest, Marshal.dump(index))
      dest
    end

    def build_all_prebuilt!(editions, force: false)
      editions.map do |edition|
        build_prebuilt!(edition.edition_id, text_path: edition.corpus_text_path, lines: edition.lines, force: force)
      end
    end

    def load_prebuilt!(path)
      VerseIndex.load_chapter_index_file(path)
    end
  end
end
