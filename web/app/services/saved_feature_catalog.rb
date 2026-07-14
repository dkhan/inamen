# frozen_string_literal: true

# Runs discovery scans for user-saved features.
class SavedFeatureCatalog
  class << self
    def row_for(saved_feature, edition, index: false)
      actual = index ? index_count(saved_feature, edition) : run_count(saved_feature, edition)
      FeatureCatalog::ResultRow.new(
        id: saved_feature.url_id,
        name: saved_feature.name,
        description: saved_feature.display_description,
        count: actual,
        expected: saved_feature.expected_count,
        unit: saved_feature.unit,
        scope: saved_feature.scope_label,
        match: actual == saved_feature.expected_count,
        kjvcode_expected: nil,
        kjvcode_match: nil,
        kjvcode_url: saved_feature.kjvcode_url.presence,
        notes: saved_feature.notes.presence,
        details: Array(saved_feature.details)
      )
    end

    def rows_for_edition(edition, index: false)
      SavedFeature.where(edition_id: edition.edition_id).order(:name).map do |saved_feature|
        row_for(saved_feature, edition, index: index)
      end
    end

    def index_count(saved_feature, edition)
      return saved_feature.saved_actual_count unless edition.edition_id == saved_feature.edition_id

      scan_params = saved_feature.to_scan_params
      return saved_feature.saved_actual_count unless DiscoveryScan.enabled_search_terms?(scan_params.query_terms)

      total = cached_total(saved_feature, edition, scan_params)
      return saved_feature.saved_actual_count if total.nil?

      if total != saved_feature.saved_actual_count
        clear_total_cache(saved_feature, edition, scan_params)
        return saved_feature.saved_actual_count
      end

      total
    rescue ArgumentError, TypeError
      saved_feature.saved_actual_count
    end

    def run_count(saved_feature, edition)
      return saved_feature.saved_actual_count unless edition.edition_id == saved_feature.edition_id

      scan_params = saved_feature.to_scan_params
      return saved_feature.saved_actual_count unless DiscoveryScan.enabled_search_terms?(scan_params.query_terms)

      total = cached_total(saved_feature, edition, scan_params)
      if total
        if total != saved_feature.saved_actual_count
          clear_total_cache(saved_feature, edition, scan_params)
        else
          return total
        end
      end

      return saved_feature.saved_actual_count unless DiscoveryScan.valid_search_terms?(edition, scan_params.query_terms)

      run_total(saved_feature, edition, scan_params)
    rescue ArgumentError, TypeError
      saved_feature.saved_actual_count
    end

    private

    # Reads the cached total for the feature's measure (verses vs occurrences),
    # or nil when that measure's results are not cached.
    def cached_total(saved_feature, edition, scan_params)
      if saved_feature.verses?
        return nil unless DiscoveryScan.verses_cached?(edition, scan_params)

        verse_result = DiscoveryScan.read_verses_cached(edition, scan_params)
        verse_result && DiscoveryScan.verse_count_total(verse_result)
      else
        return nil unless DiscoveryScan.counts_cached?(edition, scan_params)

        rows = DiscoveryScan.read_counts_cached(edition, scan_params)
        rows && DiscoveryScan.word_count_table_total(rows)
      end
    end

    # Runs the scan for the feature's measure and returns the fresh total.
    def run_total(saved_feature, edition, scan_params)
      edition.warm! if edition.corpus_ready?

      if saved_feature.verses?
        DiscoveryScan.verse_count_total(DiscoveryScan.run_verses(edition, scan_params, force: false))
      else
        DiscoveryScan.word_count_table_total(DiscoveryScan.run_counts(edition, scan_params, force: false))
      end
    end

    def clear_total_cache(saved_feature, edition, scan_params)
      if saved_feature.verses?
        DiscoveryScan.clear_verses_cache!(edition, scan_params)
      else
        DiscoveryScan.clear_counts_cache!(edition, scan_params)
      end
    end
  end
end
