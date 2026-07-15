# frozen_string_literal: true

# Verifies user-saved features against any edition and persists the per-edition
# result in feature_editions. The verification path is fully generic — it reuses
# DiscoveryScan for every feature and edition, with no edition- or feature-
# specific branches. A feature's expected value and original edition are never
# modified here.
class SavedFeatureCatalog
  class << self
    def rows_for_edition(edition, force: false)
      SavedFeature.order(:name).map { |saved_feature| row_for(saved_feature, edition, force: force) }
    end

    def row_for(saved_feature, edition, force: false)
      record = verified_edition(saved_feature, edition, force: force)
      FeatureCatalog::ResultRow.new(
        id: saved_feature.url_id,
        name: saved_feature.name,
        description: saved_feature.display_description,
        count: record.actual,
        expected: saved_feature.expected_count,
        unit: saved_feature.unit,
        scope: saved_feature.scope_label,
        match: record.status_match?,
        kjvcode_expected: nil,
        kjvcode_match: nil,
        kjvcode_url: saved_feature.kjvcode_url.presence,
        notes: saved_feature.notes.presence,
        details: Array(saved_feature.details)
      )
    end

    # One FeatureEdition per edition, computed on demand. Used by the feature
    # show page to display actuals/status across all editions.
    def results_for_all_editions(saved_feature, force: false)
      EditionContext.all_ids.map do |edition_id|
        verified_edition(saved_feature, EditionContext.new(edition_id), force: force)
      end
    end

    # Returns the persisted FeatureEdition for (feature, edition), reusing a cached
    # verified result when present, otherwise running the generic validation and
    # saving the actual value + MATCH/MISS status. Never touches the feature's
    # expected value or original edition; unique per (feature, edition).
    def verified_edition(saved_feature, edition, force: false)
      record = FeatureEdition.find_or_initialize_by(
        feature_id: saved_feature.id, edition_id: edition.edition_id
      )
      return record if !force && record.persisted? && record.processing_verified?

      actual = compute_actual(saved_feature, edition, force: force)
      record.actual = actual
      record.status = actual == saved_feature.expected_count ? FeatureEdition::STATUS_MATCH : FeatureEdition::STATUS_MISS
      record.verified_at = Time.current
      record.processing_state = :verified
      record.error = nil
      record.save!
      record
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      # Another request created it concurrently — reuse the persisted row.
      FeatureEdition.find_by(feature_id: saved_feature.id, edition_id: edition.edition_id) || raise
    rescue ArgumentError, TypeError => e
      record.processing_state = :failed
      record.error = e.message
      record.actual ||= 0
      record.status ||= FeatureEdition::STATUS_MISS
      record.save
      record
    end

    private

    # Generic occurrence/verse count for a feature's search run against an
    # edition. Reuses the same counting path as Discover — no special cases.
    def compute_actual(saved_feature, edition, force: false)
      scan_params = saved_feature.to_scan_params
      return 0 unless DiscoveryScan.enabled_search_terms?(scan_params.query_terms)
      return 0 unless DiscoveryScan.valid_search_terms?(edition, scan_params.query_terms)

      if saved_feature.verses?
        DiscoveryScan.verse_count_total(DiscoveryScan.run_verses(edition, scan_params, force: force))
      else
        DiscoveryScan.word_count_table_total(DiscoveryScan.run_counts(edition, scan_params, force: force))
      end
    end
  end
end
