# frozen_string_literal: true

require "digest"

class EditionImporter
  Result = Struct.new(:edition, :paths, keyword_init: true)

  def self.import!(file:, type:, name: nil, force: true)
    new(file: file, type: type, name: name, force: force).import!
  end

  def initialize(file:, type:, name:, force:)
    @file = Pathname(file).expand_path
    @type = type.to_s
    @name = name.to_s.strip.presence
    @force = force
  end

  def import!
    raise ArgumentError, "TYPE must be bible" unless @type == "bible"

    result = Inamen::BibleTextPreprocessor.from_file(@file)
    short_name = unique_short_name

    edition = Edition.find_or_initialize_by(short_name: short_name)
    remove_previous_generated_text_copies!(edition) if edition.persisted?
    edition.assign_attributes(
      name: @name || display_name_from_filename,
      corpus_type: @type,
      source_path: @file.to_s,
      source_filename: @file.basename.to_s,
      source_checksum: Digest::SHA256.file(@file).hexdigest,
      byte_size: @file.size,
      imported_at: Time.current,
      metadata: { books: result.books, language: result.language, canon: result.canon }.compact
    )
    edition.save!

    paths = build_artifacts!(edition, lines: result.lines)
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

  def slug(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
  end

  def remove_previous_generated_text_copies!(edition)
    [edition.source_path, edition.metadata.to_h["processed_path"]].compact.each do |path|
      next unless generated_text_copy?(path)
      next if File.expand_path(path) == @file.to_s

      File.delete(path) if File.file?(path)
    end
  end

  def generated_text_copy?(path)
    expanded = File.expand_path(path)
    root = Rails.root.join("..", "data", "imported_editions").expand_path.to_s
    expanded.start_with?("#{root}/")
  end

  def build_artifacts!(edition, lines:)
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
        lines: lines,
        source_lines: edition.source_lines,
        force: @force
      )
    }
  end
end
