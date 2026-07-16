class MoveStaticFileStatsFeaturesToSavedFeatures < ActiveRecord::Migration[8.1]
  class SavedFeature < ActiveRecord::Base
    self.table_name = "saved_features"
  end

  def up
    original_edition_id = select_value("SELECT short_name FROM editions ORDER BY created_at ASC, short_name ASC LIMIT 1") ||
                          "imported"

    upsert_feature(
      from_feature: "combined_total",
      name: "Combined token total (7^7)",
      description: "Sum of all counted Bible corpus token buckets in the edition.",
      expected_count: 823_543,
      unit: "tokens",
      scope_label: "whole bible",
      notes: "789,629 verse text + 1,034 psalm headings + 186 colophons + 567 other text + 22 psalm 119 divisions + 1,189 chapters + 31,102 verses = 823,543 = 7^7.",
      kjvcode_url: "https://kjvcode.com/pattern/elton-anomaly/",
      details: ["combined_total=823543", "7^7=823543"],
      original_edition_id: original_edition_id
    )

    upsert_feature(
      from_feature: "file_character_total",
      name: "File character total (UTF-8)",
      description: "Every Unicode code point in the edition file as stored on disk.",
      expected_count: 4_233_726,
      unit: "characters",
      scope_label: "whole file",
      notes: "4,233,726 = 7 * ceil(777.7^2). Counts code points, not raw bytes.",
      kjvcode_url: nil,
      details: ["codepoints=4233726", "7*ceil(777.7^2)=4233726"],
      original_edition_id: original_edition_id
    )
  end

  def down
    SavedFeature.where(from_feature: %w[combined_total file_character_total]).delete_all
  end

  private

  def upsert_feature(attrs)
    feature = SavedFeature.find_or_initialize_by(from_feature: attrs.fetch(:from_feature))
    feature.assign_attributes(
      name: attrs.fetch(:name),
      description: attrs.fetch(:description),
      original_edition_id: attrs.fetch(:original_edition_id),
      feature_type: "bible",
      scope_label: attrs.fetch(:scope_label),
      unit: attrs.fetch(:unit),
      expected_count: attrs.fetch(:expected_count),
      mode: "file_stats",
      search_selection: {},
      search_phrases: {},
      notes: attrs.fetch(:notes),
      kjvcode_url: attrs[:kjvcode_url],
      details: attrs.fetch(:details)
    )
    feature.save!
  end
end
