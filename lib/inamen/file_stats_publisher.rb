# frozen_string_literal: true

require "digest"
require "fileutils"

module Inamen
  # Builds and resolves precomputed whole-file stats (7^7 breakdown + character count).
  module FileStatsPublisher
    FILE_STATS_REVISION = "13"

    module_function

    def prebuilt_root
      File.expand_path("../../data/file_stats", __dir__)
    end

    def stats_filename(edition_id, checksum_prefix)
      "#{edition_id}-#{checksum_prefix}-#{FILE_STATS_REVISION}.marshal"
    end

    def prebuilt_path(edition_id, text_path:)
      File.join(prebuilt_root, stats_filename(edition_id, CorpusPublisher.checksum_prefix(text_path)))
    end

    def prebuilt_available?(edition_id, text_path:)
      File.file?(prebuilt_path(edition_id, text_path: text_path))
    end

    def build_prebuilt!(edition_id, text_path:, lines: nil, source_lines: nil, force: false)
      dest = prebuilt_path(edition_id, text_path: text_path)
      return dest if File.file?(dest) && !force

      FileUtils.mkdir_p(prebuilt_root)
      source_lines ||= File.readlines(text_path, chomp: true)
      lines ||= source_lines
      result = FileStatsReport.build(lines, text_path: text_path, source_lines: source_lines)
      result.explorer = FileStatsExplorer.resolve(
        edition_id,
        checksum: CorpusPublisher.checksum_prefix(text_path),
        chapter_index: VerseIndex.build_chapter_index(lines),
        lines: source_lines,
        source_text: File.read(text_path, encoding: "UTF-8"),
        force: force
      )
      File.binwrite(dest, Marshal.dump(result))
      dest
    end

    def build_all_prebuilt!(editions, force: false)
      editions.map do |edition|
        lines = edition.lines
        build_prebuilt!(
          edition.edition_id,
          text_path: edition.path,
          lines: lines,
          source_lines: edition.source_lines,
          force: force
        )
      end
    end

    def load_prebuilt!(path)
      Marshal.load(File.binread(path)) # rubocop:disable Security/MarshalLoad -- trusted prebuilt artifact
    end

    def load_for(edition_id, text_path:)
      path = prebuilt_path(edition_id, text_path: text_path)
      return nil unless File.file?(path)

      result = load_prebuilt!(path)
      result.explorer ||= FileStatsExplorer.load_cache(edition_id) if FileStatsExplorer.cache_current?(
        edition_id,
        CorpusPublisher.checksum_prefix(text_path)
      )
      result
    end

    def resolve(edition_id, lines:, text_path:, source_lines: nil)
      load_for(edition_id, text_path: text_path) || begin
        result = FileStatsReport.build(lines, text_path: text_path, source_lines: source_lines)
        result.explorer = FileStatsExplorer.resolve(
          edition_id,
          checksum: CorpusPublisher.checksum_prefix(text_path),
          chapter_index: VerseIndex.build_chapter_index(lines),
          lines: source_lines || lines,
          source_text: File.read(text_path, encoding: "UTF-8")
        )
        result
      end
    end
  end
end
