# frozen_string_literal: true

require "digest"
require "fileutils"

module Inamen
  # Builds and resolves precomputed whole-file stats (7^7 breakdown + character count).
  module FileStatsPublisher
    FILE_STATS_REVISION = "1"

    module_function

    def prebuilt_root
      File.join(KjvEditions::ROOT, "file_stats")
    end

    def stats_filename(edition_id, checksum_prefix)
      "#{edition_id}-#{checksum_prefix}-#{FILE_STATS_REVISION}.marshal"
    end

    def prebuilt_path(edition_id, text_path: nil)
      text_path ||= KjvEditions::EDITIONS.fetch(edition_id)
      File.join(prebuilt_root, stats_filename(edition_id, CorpusPublisher.checksum_prefix(text_path)))
    end

    def prebuilt_available?(edition_id)
      File.file?(prebuilt_path(edition_id))
    end

    def build_prebuilt!(edition_id, force: false)
      dest = prebuilt_path(edition_id)
      return dest if File.file?(dest) && !force

      FileUtils.mkdir_p(prebuilt_root)
      text_path = KjvEditions::EDITIONS.fetch(edition_id)
      lines = KjvEditions.lines_for(edition_id)
      result = FileStatsReport.build(lines, text_path: text_path)
      File.binwrite(dest, Marshal.dump(result))
      dest
    end

    def build_all_prebuilt!(force: false)
      KjvEditions::EDITIONS.keys.map { |id| build_prebuilt!(id, force: force) }
    end

    def load_prebuilt!(path)
      Marshal.load(File.binread(path)) # rubocop:disable Security/MarshalLoad -- trusted prebuilt artifact
    end

    def load_for(edition_id)
      path = prebuilt_path(edition_id)
      return nil unless File.file?(path)

      load_prebuilt!(path)
    end

    def resolve(edition_id, lines: nil, text_path: nil)
      load_for(edition_id) || begin
        lines ||= KjvEditions.lines_for(edition_id)
        text_path ||= KjvEditions::EDITIONS.fetch(edition_id)
        FileStatsReport.build(lines, text_path: text_path)
      end
    end
  end
end
