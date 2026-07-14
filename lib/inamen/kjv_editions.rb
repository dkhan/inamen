# frozen_string_literal: true

module Inamen
  # Known plain-text KJV editions bundled under data/.
  module KjvEditions
    ROOT = File.expand_path("../../data", __dir__)

    EDITIONS = {
      "kjv_normalized" => File.join(ROOT, "KJV.txt"),
      "concord" => File.join(ROOT, "Holy-Bible-King-James-Version-Entire-Bible-Concord.txt")
    }.freeze

    # Edition-specific pass targets when Concord text differs from the reference KJV.txt catalog.
    FEATURE_OVERRIDES = {}.freeze

    # Features that intentionally differ from the reference catalog (shown as MISS, not a regression).
    CATALOG_DIFFERS = {
      "concord" => %w[file_character_total].freeze
    }.freeze

    def self.expected_feature_count(edition_id, feature_id)
      FEATURE_OVERRIDES.dig(edition_id, feature_id) ||
        Features.catalog.find { |entry| entry.id == feature_id }&.expected_count
    end

    def self.verify_edition_feature?(edition_id, feature_id)
      !CATALOG_DIFFERS.fetch(edition_id, []).include?(feature_id)
    end

    def self.paths
      EDITIONS.values
    end

    def self.lines_for(id)
      path = EDITIONS.fetch(id) { raise ArgumentError, "Unknown KJV edition: #{id.inspect}" }
      read_lines(path)
    end

    def self.read_lines(path)
      lines = File.readlines(path, chomp: true)
      edition_id = EDITIONS.key(path)
      edition_id == "concord" ? ConcordNormalizer.normalize(lines) : lines
    end
  end
end
