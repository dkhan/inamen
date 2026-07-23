# frozen_string_literal: true

require "test_helper"
require "fileutils"

class EditionRemoverTest < ActiveSupport::TestCase
  test "removes edition records and generated artifacts while preserving the data source" do
    edition_id = "remove_me_test"
    data_root = Rails.root.join("..", "data").expand_path
    source_path = data_root.join("REMOVE_ME_TEST.txt")
    generated_text_path = data_root.join("imported_editions", "#{edition_id}.txt")
    artifact_paths = EditionRemover::ARTIFACT_ROOTS.map do |root|
      Pathname(root).join("#{edition_id}-artifact.marshal")
    end
    artifact_dir = Inamen::FileStatsExplorer.cache_dir(edition_id)
    unrelated_artifact_path = Pathname(EditionRemover::ARTIFACT_ROOTS.first).join("keep_me_test-artifact.marshal")

    FileUtils.mkdir_p(generated_text_path.dirname)
    File.write(source_path, "Genesis\n1\n1 In the beginning.\n")
    File.write(generated_text_path, "processed copy")
    (artifact_paths + [unrelated_artifact_path]).each do |path|
      FileUtils.mkdir_p(path.dirname)
      File.write(path, "generated")
    end
    FileUtils.mkdir_p(artifact_dir)
    File.write(File.join(artifact_dir, "manifest.csv"), "key,value\n")

    edition = Edition.create!(
      short_name: edition_id,
      name: "Remove Me Test",
      corpus_type: "bible",
      source_path: source_path.to_s,
      source_filename: source_path.basename.to_s,
      source_checksum: Digest::SHA256.file(source_path).hexdigest,
      byte_size: source_path.size,
      imported_at: Time.current,
      metadata: { "processed_path" => generated_text_path.to_s }
    )
    feature = SavedFeature.create!(
      name: "Remove Me Test Feature",
      original_edition_id: edition.short_name,
      expected_count: 1,
      scope_label: "whole Bible",
      search_phrases: { "0" => { "phrase" => "beginning" } }
    )
    FeatureEdition.create!(
      saved_feature: feature,
      edition_id: edition.short_name,
      actual: 1,
      status: FeatureEdition::STATUS_MATCH,
      processing_state: "verified"
    )
    FeatureEdition.create!(
      saved_feature: feature,
      edition_id: "keep_me_test",
      actual: 1,
      status: FeatureEdition::STATUS_MATCH,
      processing_state: "verified"
    )

    result = EditionRemover.remove!(edition_id: edition.short_name)

    assert_nil Edition.find_by(short_name: edition.short_name)
    assert File.file?(source_path), "source file in data should be preserved"
    assert_not File.exist?(generated_text_path), "generated text copy should be removed"
    artifact_paths.each { |path| assert_not File.exist?(path), "#{path} should be removed" }
    assert_not File.exist?(artifact_dir), "#{artifact_dir} should be removed"
    assert File.file?(unrelated_artifact_path), "unrelated artifacts should be preserved"
    assert_equal artifact_paths.map(&:to_s).sort, result.deleted_artifacts.sort
    assert_equal [artifact_dir], result.deleted_artifact_dirs
    assert_equal [generated_text_path.to_s], result.deleted_generated_texts
    assert_equal 1, result.deleted_feature_editions
    assert_nil FeatureEdition.find_by(edition_id: edition.short_name)
    assert FeatureEdition.find_by(edition_id: "keep_me_test")
  ensure
    FeatureEdition.where(edition_id: [edition_id, "keep_me_test"]).delete_all
    SavedFeature.where(name: "Remove Me Test Feature").delete_all
    Edition.where(short_name: edition_id).delete_all
    ([source_path, generated_text_path, unrelated_artifact_path].compact + Array(artifact_paths)).each do |path|
      FileUtils.rm_f(path)
    end
    FileUtils.rm_rf(artifact_dir) if artifact_dir
  end
end
