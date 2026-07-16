# frozen_string_literal: true

require "test_helper"

class FeaturesHelperTest < ActionView::TestCase
  EDITION_ID = "kjv_normalized"

  def create_saved_feature
    SavedFeature.create!(
      name: "My Peter scan",
      original_edition_id: EDITION_ID,
      scope_label: "All texts",
      unit: SavedFeature::UNIT_OCCURRENCES,
      mode: "word_count",
      expected_count: 153,
      search_selection: { "submitted" => "1" },
      search_phrases: { "0" => { "phrase" => "peter" } }
    )
  end

  test "MATCH for a saved feature loads generic search criteria and a durable feature id" do
    feature = create_saved_feature
    captured = nil

    DiscoverQueryStore.stub(:write, ->(_token, query) { captured = query; "tok" }) do
      path = feature_discover_path_for(feature.url_id, edition: EDITION_ID)
      assert_includes path, "dq=tok"
      assert_includes path, "feature=#{feature.url_id}"
      assert_includes path, "auto_scan=1"
    end

    assert_equal %w[mode search_selection search_phrases from_feature], captured.keys
    assert_equal feature.url_id, captured["from_feature"]
    assert_equal "word_count", captured["mode"]
    assert_equal({ "0" => { "phrase" => "peter" } }, captured["search_phrases"])
  end

  test "MATCH for a file stats saved feature opens the file-stats view" do
    feature = SavedFeature.create!(
      name: "Characters",
      original_edition_id: EDITION_ID,
      scope_label: "whole file",
      unit: SavedFeature::UNIT_CHARACTERS,
      mode: "file_stats",
      expected_count: 4_233_726,
      search_selection: {},
      search_phrases: {},
      from_feature: "file_character_total"
    )

    path = feature_discover_path_for(feature.url_id, edition: EDITION_ID)

    assert_includes path, "mode=file_stats"
    assert_includes path, "highlight=file_characters"
    refute_includes path, "dq="
  end
end
