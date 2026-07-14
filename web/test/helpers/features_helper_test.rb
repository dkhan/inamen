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

  test "MATCH for a saved feature loads only generic search criteria" do
    feature = create_saved_feature
    captured = nil

    DiscoverQueryStore.stub(:write, ->(_token, query) { captured = query; "tok" }) do
      path = feature_discover_path_for(feature.url_id, edition: EDITION_ID)
      assert_includes path, "dq=tok"
      assert_includes path, "auto_scan=1"
    end

    # Only generic search criteria are stored — no feature identity/source.
    assert_equal %w[mode search_selection search_phrases], captured.keys
    refute captured.key?("from_feature")
    refute captured.key?(:from_feature)
    assert_equal "word_count", captured["mode"]
    assert_equal({ "0" => { "phrase" => "peter" } }, captured["search_phrases"])
  end

  test "MATCH for a built-in feature opens the file-stats view without a feature identity" do
    path = feature_discover_path_for("combined_total", edition: EDITION_ID)

    assert_includes path, "mode=file_stats"
    assert_includes path, "highlight=combined_total"
    refute_includes path, "dq="
    refute_includes path, "from_feature"
  end
end
