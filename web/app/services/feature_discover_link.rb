# frozen_string_literal: true

# Builds Discover URLs that reproduce a catalog feature as a word-count scan.
class FeatureDiscoverLink
  class << self
    def query_for(feature_id, edition_id:)
      return nil unless Inamen::FeatureDiscoverPresets.discoverable?(feature_id)

      mode = Inamen::FeatureDiscoverPresets.discover_mode_for(feature_id)
      query = {
        edition: edition_id.to_s,
        mode: mode
      }

      highlight = Inamen::FeatureDiscoverPresets.discover_highlight_for(feature_id)
      query[:highlight] = highlight if highlight

      return query if mode == "file_stats"

      query[:auto_scan] = "1"
      phrases = Inamen::FeatureDiscoverPresets.phrase_entries_for(feature_id)

      query[:search_phrases] = phrases.each_with_index.to_h do |phrase, index|
        row = { phrase: phrase[:phrase] }
        row[:case_sensitive] = "1" if phrase[:case_sensitive]
        row[:exclude] = "1" if phrase[:exclude]
        row[:disabled] = "1" if phrase[:disabled]
        [index.to_s, row]
      end

      query[:search_selection] = Inamen::FeatureDiscoverPresets.selection_query_for(feature_id)

      query
    end
  end
end
