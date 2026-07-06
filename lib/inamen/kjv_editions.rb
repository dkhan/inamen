# frozen_string_literal: true

module Inamen
  # Known plain-text KJV editions bundled under data/.
  module KjvEditions
    ROOT = File.expand_path("../../data", __dir__)

    EDITIONS = {
      "kjv_normalized" => File.join(ROOT, "KJV.txt"),
      "concord" => File.join(ROOT, "Holy-Bible-King-James-Version-Entire-Bible-Concord.txt")
    }.freeze

    # Text-level variants (capitalization, The*, God*) vs the reference KJV.txt catalog counts.
    FEATURE_OVERRIDES = {
      "concord" => {
        "the_amen_nt_concealed" => 981,
        "god_pure_nt" => 1369,
        "jesus_boundary_same_verse" => 2398,
        "file_character_total" => 4_241_503
      }
    }.freeze

    def self.expected_feature_count(edition_id, feature_id)
      FEATURE_OVERRIDES.dig(edition_id, feature_id) ||
        Features.catalog.find { |entry| entry.id == feature_id }&.expected_count
    end

    def self.paths
      EDITIONS.values
    end

    def self.lines_for(id)
      path = EDITIONS.fetch(id) { raise ArgumentError, "Unknown KJV edition: #{id.inspect}" }
      File.readlines(path, chomp: true)
    end

    def self.read_lines(path)
      File.readlines(path, chomp: true)
    end
  end
end
