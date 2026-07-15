# frozen_string_literal: true

require "digest"
require "fileutils"

class EditionImporter
  IMPORT_ROOT = Rails.root.join("..", "data", "imported_editions").expand_path
  ORIGINAL_ROOT = IMPORT_ROOT.join("originals")
  PROCESSED_ROOT = IMPORT_ROOT.join("processed")

  Result = Struct.new(:edition, :paths, keyword_init: true)

  def self.import!(file:, type:, name: nil, force: true)
    new(file: file, type: type, name: name, force: force).import!
  end

  def initialize(file:, type:, name:, force:)
    @file = Pathname(file)
    @type = type.to_s
    @name = name.to_s.strip.presence
    @force = force
  end

  def import!
    raise ArgumentError, "TYPE must be bible" unless @type == "bible"

    result = Inamen::BibleTextPreprocessor.from_file(@file)
    short_name = unique_short_name
    original_dest = original_text_path(short_name)
    processed_dest = processed_text_path(short_name)

    FileUtils.mkdir_p(ORIGINAL_ROOT)
    FileUtils.mkdir_p(PROCESSED_ROOT)
    FileUtils.cp(@file, original_dest)
    File.write(processed_dest, result.lines.join("\n") + "\n", mode: "w:UTF-8")

    edition = Edition.find_or_initialize_by(short_name: short_name)
    edition.assign_attributes(
      name: @name || display_name_from_filename,
      corpus_type: @type,
      source_path: original_dest.to_s,
      source_filename: @file.basename.to_s,
      source_checksum: Digest::SHA256.file(original_dest).hexdigest,
      byte_size: original_dest.size,
      imported_at: Time.current,
      metadata: { books: result.books, processed_path: processed_dest.to_s }
    )
    edition.save!

    paths = build_artifacts!(edition)
    Result.new(edition: edition, paths: paths)
  rescue Inamen::BibleTextPreprocessor::Error => e
    raise ArgumentError, e.message
  end

  private

  def unique_short_name
    existing = Edition.find_by(source_filename: @file.basename.to_s)
    return existing.short_name if existing && @name.blank?

    base = slug(@name || @file.basename(".*").to_s)
    base = "edition" if base.blank?
    return base if Edition.where(short_name: base).none?
    return base if Edition.find_by(short_name: base)&.source_filename == @file.basename.to_s

    counter = 2
    loop do
      candidate = "#{base}-#{counter}"
      return candidate if Edition.where(short_name: candidate).none?

      counter += 1
    end
  end

  def display_name_from_filename
    @file.basename(".*").to_s.tr("_-", " ").squeeze(" ").split.map(&:capitalize).join(" ")
  end

  def original_text_path(short_name)
    ORIGINAL_ROOT.join("#{short_name}.txt")
  end

  def processed_text_path(short_name)
    PROCESSED_ROOT.join("#{short_name}.txt")
  end

  def slug(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
  end

  def build_artifacts!(edition)
    lines = edition.lines
    corpus = Inamen::CorpusPublisher.build_prebuilt!(
      edition.edition_id,
      text_path: edition.corpus_text_path,
      lines: lines,
      force: @force
    )
    {
      corpus: corpus,
      verse_index: Inamen::VerseIndexPublisher.build_prebuilt!(
        edition.edition_id,
        text_path: edition.corpus_text_path,
        lines: lines,
        force: @force
      ),
      word_stream: Inamen::WordStreamPublisher.build_prebuilt!(
        edition.edition_id,
        text_path: edition.corpus_text_path,
        corpus_path: corpus,
        force: @force
      ),
      lexicon: Inamen::LexiconPublisher.build_prebuilt!(
        edition.edition_id,
        text_path: edition.corpus_text_path,
        corpus_path: corpus,
        force: @force
      ),
      canon_ordinals: Inamen::CanonOrdinalsPublisher.build_prebuilt!(
        edition.edition_id,
        text_path: edition.corpus_text_path,
        corpus_path: corpus,
        force: @force
      ),
      file_stats: Inamen::FileStatsPublisher.build_prebuilt!(
        edition.edition_id,
        text_path: edition.path,
        lines: edition.source_lines,
        force: @force
      )
    }
  end
end
