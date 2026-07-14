# frozen_string_literal: true

require "test_helper"

# Guarantees around the two remaining built-in features and the fully generic
# Discover pipeline after the hard-coded features/presets were removed.
class BuiltinFeaturesTest < ActionDispatch::IntegrationTest
  EDITION_ID = "kjv_normalized"
  BUILT_INS = %w[combined_total file_character_total].freeze

  def create_saved_feature(name: "My Peter scan", phrase: "peter")
    SavedFeature.create!(
      name: name,
      edition_id: EDITION_ID,
      scope_label: "All texts",
      unit: SavedFeature::UNIT_OCCURRENCES,
      mode: "word_count",
      expected_count: 153,
      saved_actual_count: 153,
      search_selection: { "submitted" => "1" },
      search_phrases: { "0" => { "phrase" => phrase } }
    )
  end

  test "only combined_total and file_character_total remain built in" do
    assert_equal BUILT_INS, Inamen::Features.catalog.map(&:id)
  end

  test "removed preset and feature-specific modules no longer exist" do
    refute defined?(Inamen::FeatureDiscoverPresets), "FeatureDiscoverPresets should be removed"
    refute defined?(Inamen::FishermenNameCounts), "FishermenNameCounts should be removed"
    refute defined?(Inamen::FishermenGospelsKjs), "FishermenGospelsKjs should be removed"
    refute defined?(Inamen::JesusMentionsAntimentions), "JesusMentionsAntimentions should be removed"
    refute defined?(Inamen::BibleBoundaryPatterns), "BibleBoundaryPatterns should be removed"
    refute defined?(Inamen::KjvcodeAlignment), "KjvcodeAlignment should be removed"
  end

  test "the scan pipeline carries no feature identity" do
    refute_includes DiscoveryScan::Params.members, :from_feature
    # A stray from_feature key is ignored rather than retained.
    params = DiscoveryScan.normalize(mode: "word_count", from_feature: "jesus_mentions",
                                     search_phrases: { "0" => { "phrase" => "peter" } })
    refute params.respond_to?(:from_feature)
  end

  test "built-in features cannot be edited" do
    BUILT_INS.each do |id|
      get edit_feature_path(id, edition: EDITION_ID)
      assert_response :not_found, "expected #{id} edit to 404"
    end
  end

  test "built-in features cannot be deleted" do
    BUILT_INS.each do |id|
      assert_no_difference "SavedFeature.count" do
        delete feature_path(id, edition: EDITION_ID)
      end
      assert_response :not_found, "expected #{id} delete to 404"
    end
  end

  test "persisted saved features can still be edited, updated, and deleted" do
    feature = create_saved_feature

    DiscoveryScan.stub(:enabled_search_terms?, false) do
      get edit_feature_path(feature.url_id, edition: EDITION_ID)
    end
    assert_response :success

    patch feature_path(feature.url_id, edition: EDITION_ID),
          params: { saved_feature: { name: "Renamed scan" } }
    assert_redirected_to feature_path(feature.url_id, edition: EDITION_ID)
    assert_equal "Renamed scan", feature.reload.name

    assert_difference "SavedFeature.count", -1 do
      delete feature_path(feature.url_id, edition: EDITION_ID)
    end
  end

  test "persisted saved features still match and check generically" do
    feature = create_saved_feature
    edition = EditionContext.new(EDITION_ID)

    row = nil
    DiscoveryScan.stub(:enabled_search_terms?, true) do
      DiscoveryScan.stub(:counts_cached?, true) do
        DiscoveryScan.stub(:read_counts_cached, [DiscoveryScan::WordCountRow.new(
          pattern: "peter", case_sensitive: false, count: 153, wildcard: false,
          scope: "All texts", spellings: {}, exclude: false
        )]) do
          row = SavedFeatureCatalog.row_for(feature, edition, index: true)
        end
      end
    end

    assert_equal 153, row.count
    assert row.match
  end

  test "editing and rerunning a matched search does not alter the saved feature" do
    feature = create_saved_feature(phrase: "peter")
    before = feature.attributes

    # Simulate the user editing the loaded criteria (peter -> paul) and rerunning.
    DiscoveryScan.stub(:valid_search_terms?, true) do
      DiscoveryScan.stub(:counts_cached?, true) do
        DiscoveryScan.stub(:enqueue_verses!, nil) do
          post scan_discoveries_path, params: {
            edition: EDITION_ID,
            mode: "word_count",
            search_selection: { submitted: "1", books: ["Genesis"] },
            search_phrases: { "0" => { phrase: "paul" } }
          }
        end
      end
    end

    assert_response :redirect
    assert_equal before, feature.reload.attributes
  end
end
