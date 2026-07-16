# frozen_string_literal: true

require "test_helper"

class FileStatsSavedFeaturesTest < ActionDispatch::IntegrationTest
  EDITION_ID = "kjv_normalized"

  FileStats = Struct.new(:total, :character_count, keyword_init: true)

  def create_file_stats_feature(unit:, expected:, from_feature:)
    SavedFeature.create!(
      name: "#{unit.capitalize} total",
      description: "#{unit.capitalize} total",
      original_edition_id: EDITION_ID,
      feature_type: "bible",
      scope_label: unit == "characters" ? "whole file" : "whole bible",
      unit: unit,
      mode: "file_stats",
      expected_count: expected,
      search_selection: {},
      search_phrases: {},
      from_feature: from_feature
    )
  end

  test "file stats saved features verify tokens and characters generically" do
    tokens = create_file_stats_feature(unit: "tokens", expected: 823_543, from_feature: "combined_total")
    chars = create_file_stats_feature(unit: "characters", expected: 4_233_726, from_feature: "file_character_total")
    stats = FileStats.new(total: 823_543, character_count: 4_233_726)

    DiscoveryScan.stub(:run_file_stats, stats) do
      token_row = SavedFeatureCatalog.row_for(tokens, EditionContext.new(EDITION_ID), force: true)
      char_row = SavedFeatureCatalog.row_for(chars, EditionContext.new(EDITION_ID), force: true)

      assert_equal 823_543, token_row.count
      assert token_row.match
      assert_equal 4_233_726, char_row.count
      assert char_row.match
    end
  end

  test "file stats saved feature status opens Discover file stats" do
    feature = create_file_stats_feature(unit: "characters", expected: 4_233_726,
                                        from_feature: "file_character_total")

    get feature_path(feature.url_id, edition: EDITION_ID)

    assert_response :success
    assert_select "a.feature-discover-status-link[href*='mode=file_stats'][href*='highlight=file_characters']"
  end

  test "file stats saved features are editable and deletable" do
    feature = create_file_stats_feature(unit: "characters", expected: 4_233_726,
                                        from_feature: "file_character_total")

    get edit_feature_path(feature.url_id, edition: EDITION_ID)
    assert_response :success

    patch feature_path(feature.url_id, edition: EDITION_ID),
          params: { saved_feature: { name: "Renamed character total", expected_count: 4_241_503 } }
    assert_redirected_to feature_path(feature.url_id, edition: EDITION_ID)
    assert_equal "Renamed character total", feature.reload.name
    assert_equal 4_241_503, feature.expected_count

    assert_difference "SavedFeature.count", -1 do
      delete feature_path(feature.url_id, edition: EDITION_ID)
    end
  end
end
