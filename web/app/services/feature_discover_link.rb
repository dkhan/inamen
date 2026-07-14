# frozen_string_literal: true

# Builds Discover URLs for the two built-in file-stats totals. Every other
# feature is a user-defined saved feature and is linked into Discover via its
# stored search criteria (see FeaturesHelper#feature_discover_path_for).
class FeatureDiscoverLink
  # Maps each built-in file-stats feature to the row it highlights in the
  # Discover file-stats table.
  HIGHLIGHTS = {
    "combined_total" => "combined_total",
    "file_character_total" => "file_characters"
  }.freeze

  class << self
    def query_for(feature_id, edition_id:)
      highlight = HIGHLIGHTS[feature_id.to_s]
      return nil unless highlight

      {
        edition: edition_id.to_s,
        mode: "file_stats",
        highlight: highlight
      }
    end
  end
end
