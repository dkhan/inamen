# frozen_string_literal: true

require "fileutils"
require "pathname"

# Removes an imported edition from the database and deletes generated artifacts.
# The original source text is intentionally preserved, especially files under
# the repository's data/ directory.
class EditionRemover
  Result = Struct.new(
    :edition_id,
    :source_path,
    :deleted_artifacts,
    :deleted_artifact_dirs,
    :deleted_generated_texts,
    :deleted_feature_editions,
    keyword_init: true
  )

  ARTIFACT_ROOTS = [
    Inamen::CorpusPublisher.prebuilt_root,
    Inamen::VerseIndexPublisher.prebuilt_root,
    Inamen::WordStreamPublisher.prebuilt_root,
    Inamen::LexiconPublisher.prebuilt_root,
    Inamen::CanonOrdinalsPublisher.prebuilt_root,
    Inamen::FileStatsPublisher.prebuilt_root,
    Rails.root.join("tmp", "corpora")
  ].freeze

  GENERATED_TEXT_ROOTS = [
    Rails.root.join("..", "data", "imported_editions").expand_path,
    Rails.root.join("..", "data", "processed").expand_path
  ].freeze

  def self.remove!(edition_id:)
    new(edition_id: edition_id).remove!
  end

  def initialize(edition_id:)
    @edition_id = edition_id.to_s.strip
    raise ArgumentError, "EDITION is required" if @edition_id.blank?
  end

  def remove!
    edition = Edition.find_by!(short_name: @edition_id)
    source_path = edition.source_path
    generated_texts = generated_text_paths_for(edition)
    artifacts = artifact_paths_for(edition.short_name)
    artifact_dirs = artifact_dirs_for(edition.short_name)

    deleted_feature_editions = 0
    Edition.transaction do
      deleted_feature_editions = FeatureEdition.where(edition_id: edition.short_name).delete_all
      edition.destroy!
    end

    deleted_artifacts = delete_files(artifacts)
    deleted_artifact_dirs = delete_dirs(artifact_dirs)
    deleted_generated_texts = delete_files(generated_texts)

    Result.new(
      edition_id: @edition_id,
      source_path: source_path,
      deleted_artifacts: deleted_artifacts,
      deleted_artifact_dirs: deleted_artifact_dirs,
      deleted_generated_texts: deleted_generated_texts,
      deleted_feature_editions: deleted_feature_editions
    )
  rescue ActiveRecord::RecordNotFound
    raise ArgumentError, "unknown edition: #{@edition_id}"
  end

  private

  def artifact_paths_for(edition_id)
    ARTIFACT_ROOTS.flat_map do |root|
      Dir.glob(Pathname(root).join("#{edition_id}-*").to_s)
    end.uniq
  end

  def artifact_dirs_for(edition_id)
    [Inamen::FileStatsExplorer.cache_dir(edition_id)]
  end

  def generated_text_paths_for(edition)
    [edition.metadata.to_h["processed_path"], edition.source_path].compact.filter_map do |path|
      expanded = Pathname(path).expand_path
      next unless generated_text_path?(expanded)

      expanded.to_s
    end
  end

  def generated_text_path?(path)
    GENERATED_TEXT_ROOTS.any? do |root|
      path.to_s.start_with?("#{root}/")
    end
  end

  def delete_files(paths)
    paths.each_with_object([]) do |path, deleted|
      next unless File.file?(path)

      FileUtils.rm_f(path)
      deleted << path unless File.exist?(path)
    end
  end

  def delete_dirs(paths)
    paths.each_with_object([]) do |path, deleted|
      next unless File.directory?(path)

      FileUtils.rm_rf(path)
      deleted << path unless File.exist?(path)
    end
  end
end
