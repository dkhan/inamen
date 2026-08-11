# frozen_string_literal: true

# Verifies user-saved features against any edition and persists the per-edition
# result in feature_editions. The verification path is fully generic — it reuses
# DiscoveryScan for every feature and edition, with no edition- or feature-
# specific branches. A feature's expected value and original edition are never
# modified here.
class SavedFeatureCatalog
  ResultRow = Struct.new(
    :id, :name, :description, :count, :expected, :unit, :scope, :match,
    :kjvcode_expected, :kjvcode_match, :kjvcode_url, :notes, :details,
    keyword_init: true
  )

  class << self
    def rows_for_edition(edition, force: false)
      SavedFeature.for_language(edition.language).order(:name).map do |saved_feature|
        row_for(saved_feature, edition, force: force)
      end
    end

    def row_for(saved_feature, edition, force: false)
      record = verified_edition(saved_feature, edition, force: force)
      ResultRow.new(
        id: saved_feature.url_id,
        name: saved_feature.name,
        description: saved_feature.display_description,
        count: record.actual,
        expected: saved_feature.expected_count,
        unit: saved_feature.unit,
        scope: saved_feature.display_scope_label,
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
        edition = EditionContext.new(edition_id)
        next unless saved_feature.language == edition.language
        if saved_feature.file_stats?
          record = FeatureEdition.find_by(feature_id: saved_feature.id, edition_id: edition.edition_id)
          snapshot = FileStatsStore.current_snapshot_for(edition.edition)
          next record if !force && record&.processing_verified? && snapshot
          next unless snapshot
        end

        verified_edition(saved_feature, edition, force: force)
      end.compact
    end

    # Returns the persisted FeatureEdition for (feature, edition), reusing a cached
    # verified result when present, otherwise running the generic validation and
    # saving the actual value + MATCH/MISS status. Never touches the feature's
    # expected value or original edition; unique per (feature, edition).
    def verified_edition(saved_feature, edition, force: false)
      record = FeatureEdition.find_or_initialize_by(
        feature_id: saved_feature.id, edition_id: edition.edition_id
      )
      return record if !force && reusable_verified_record?(saved_feature, edition, record)

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

    def reusable_verified_record?(saved_feature, edition, record)
      return false unless record.persisted? && record.processing_verified?
      return true unless saved_feature.file_stats?

      FileStatsStore.current_snapshot_for(edition.edition).present?
    end

    # Generic occurrence/verse count for a feature's search run against an
    # edition. Reuses the same counting path as Discover — no special cases.
    def compute_actual(saved_feature, edition, force: false)
      scan_params = saved_feature.to_scan_params
      if saved_feature.file_stats?
        stats = DiscoveryScan.run_file_stats(edition, scan_params, force: force)
        return stats.character_count if saved_feature.characters?

        return stats.total
      end

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
