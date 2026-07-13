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

      if DiscoveryScan.counts_cached?(edition, scan_params)
        rows = DiscoveryScan.read_counts_cached(edition, scan_params)
        if rows
          total = DiscoveryScan.word_count_table_total(rows)
          if total != saved_feature.saved_actual_count
            DiscoveryScan.clear_counts_cache!(edition, scan_params)
            return saved_feature.saved_actual_count
          end
          return total
        end
      end

      saved_feature.saved_actual_count
    rescue ArgumentError, TypeError
      saved_feature.saved_actual_count
    end

    def run_count(saved_feature, edition)
      return saved_feature.saved_actual_count unless edition.edition_id == saved_feature.edition_id

      scan_params = saved_feature.to_scan_params
      return saved_feature.saved_actual_count unless DiscoveryScan.enabled_search_terms?(scan_params.query_terms)

      if DiscoveryScan.counts_cached?(edition, scan_params)
        rows = DiscoveryScan.read_counts_cached(edition, scan_params)
        if rows
          total = DiscoveryScan.word_count_table_total(rows)
          if total != saved_feature.saved_actual_count
            DiscoveryScan.clear_counts_cache!(edition, scan_params)
          else
            return total
          end
        end
      end

      return saved_feature.saved_actual_count unless DiscoveryScan.valid_search_terms?(edition, scan_params.query_terms)

      edition.warm! if edition.corpus_ready?
      rows = DiscoveryScan.run_counts(edition, scan_params, force: false)
      DiscoveryScan.word_count_table_total(rows)
    rescue ArgumentError, TypeError
      saved_feature.saved_actual_count
    end
  end
end
