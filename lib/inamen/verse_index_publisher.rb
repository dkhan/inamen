# frozen_string_literal: true

require "digest"
require "fileutils"

module Inamen
  # Builds and resolves prebuilt chapter-indexed verse maps shipped beside bundled editions.
  module VerseIndexPublisher
    VERSE_INDEX_REVISION = "1"

    module_function

    def prebuilt_root
      File.join(KjvEditions::ROOT, "verse_indices")
    end

    def index_filename(edition_id, checksum_prefix)
      "#{edition_id}-#{checksum_prefix}-#{VERSE_INDEX_REVISION}.marshal"
    end

    def prebuilt_path(edition_id, text_path: nil)
      text_path ||= KjvEditions::EDITIONS.fetch(edition_id)
      File.join(prebuilt_root, index_filename(edition_id, CorpusPublisher.checksum_prefix(text_path)))
    end

    def prebuilt_available?(edition_id)
      File.file?(prebuilt_path(edition_id))
    end

    def build_prebuilt!(edition_id, force: false)
      dest = prebuilt_path(edition_id)
      return dest if File.file?(dest) && !force

      FileUtils.mkdir_p(prebuilt_root)
      lines = KjvEditions.lines_for(edition_id)
      index = VerseIndex.build_chapter_index(lines)
      File.binwrite(dest, Marshal.dump(index))
      dest
    end

    def build_all_prebuilt!(force: false)
      KjvEditions::EDITIONS.keys.map { |id| build_prebuilt!(id, force: force) }
    end

    def load_prebuilt!(path)
      VerseIndex.load_chapter_index_file(path)
    end
  end
end
