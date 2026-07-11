# frozen_string_literal: true

# Runs discovery scans for user-saved features.
class SavedFeatureCatalog
  class << self
    def row_for(saved_feature, edition)
      actual = run_count(saved_feature, edition)
      FeatureCatalog::ResultRow.new(
        id: saved_feature.url_id,
        name: saved_feature.name,
        description: "Saved from Discover",
        count: actual,
        expected: saved_feature.expected_count,
        unit: saved_feature.unit,
        scope: saved_feature.scope_label,
        match: actual == saved_feature.expected_count,
        kjvcode_expected: nil,
        kjvcode_match: nil,
        kjvcode_url: nil,
        notes: "Saved #{saved_feature.created_at.to_fs(:long)}",
        details: Array(saved_feature.details)
      )
    end

    def rows_for_edition(edition)
      SavedFeature.where(edition_id: edition.edition_id).order(:name).map do |saved_feature|
        row_for(saved_feature, edition)
      end
    end

    def run_count(saved_feature, edition)
      return saved_feature.saved_actual_count unless edition.edition_id == saved_feature.edition_id

      scan_params = saved_feature.to_scan_params
      return saved_feature.saved_actual_count unless DiscoveryScan.enabled_search_terms?(scan_params.query_terms)
      return saved_feature.saved_actual_count unless DiscoveryScan.valid_search_terms?(edition, scan_params.query_terms)

      edition.warm! if edition.corpus_ready?
      rows = DiscoveryScan.run_counts(edition, scan_params, force: false)
      DiscoveryScan.word_count_table_total(rows)
    rescue ArgumentError, TypeError
      saved_feature.saved_actual_count
    end
  end
end
