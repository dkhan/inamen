# frozen_string_literal: true

require "test_helper"

class FeaturesControllerTest < ActionDispatch::IntegrationTest
  EDITION_ID = "kjv_normalized"

  WordRow = Struct.new(:count, :exclude, :overlap, keyword_init: true)

  def word_rows(total)
    [WordRow.new(count: total, exclude: false, overlap: false)]
  end

  def verse_result(verses)
    summary = Inamen::VerseMatchQuery::Summary.new(
      occurrences: 158, verses: verses, chapters: 40, books: 20, scope_label: "All texts"
    )
    Inamen::VerseMatchQuery::Result.new(summary: summary, verses: [], hits: [])
  end

  def discover_query
    {
      "mode" => "word_count",
      "search_selection" => { "submitted" => "1" },
      "search_phrases" => { "0" => { "phrase" => "peter" } }
    }
  end

  def feature_params(unit:, description: nil)
    saved_feature = {
      name: "Peter (#{unit})",
      edition_id: EDITION_ID,
      scope_label: "All texts",
      unit: unit,
      mode: "word_count",
      # Intentionally wrong values: the server must overwrite them from the
      # cached search results for the selected measure.
      saved_actual_count: "999",
      expected_count: "999",
      search_selection_json: { "submitted" => "1" }.to_json,
      search_phrases_json: { "0" => { "phrase" => "peter" } }.to_json
    }
    saved_feature[:description] = description if description

    { edition: EDITION_ID, saved_feature: saved_feature }
  end

  test "new offers both measures populated from the current search results" do
    DiscoverQueryStore.stub(:fetch, discover_query) do
      DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
        DiscoveryScan.stub(:read_verses_cached, verse_result(153)) do
          get new_feature_path(edition: EDITION_ID, dq: "token")
        end
      end
    end

    assert_response :success
    assert_select "select[name=?]", "saved_feature[unit]"
    assert_select "select[name=?] option[value=?]", "saved_feature[unit]", "occurrences"
    assert_select "select[name=?] option[value=?]", "saved_feature[unit]", "verses"
    # Both measure totals are embedded so the dropdown can switch without a re-scan.
    counts = CGI.unescapeHTML(@response.body)
    assert_includes counts, "\"occurrences\":158"
    assert_includes counts, "\"verses\":153"
    # Actual/Expected are read-only.
    assert_select "input[name=?][readonly]", "saved_feature[saved_actual_count]"
    assert_select "input[name=?][readonly]", "saved_feature[expected_count]"
  end

  test "create saves the occurrences total for the occurrences measure" do
    DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
      assert_difference "SavedFeature.count", 1 do
        post features_path, params: feature_params(unit: "occurrences")
      end
    end

    feature = SavedFeature.order(:id).last
    assert_equal "occurrences", feature.unit
    assert_equal 158, feature.saved_actual_count
    assert_equal 158, feature.expected_count
    assert_redirected_to features_path(edition: EDITION_ID)
  end

  test "create saves the verse total for the verses measure" do
    DiscoveryScan.stub(:read_verses_cached, verse_result(153)) do
      assert_difference "SavedFeature.count", 1 do
        post features_path, params: feature_params(unit: "verses")
      end
    end

    feature = SavedFeature.order(:id).last
    assert_equal "verses", feature.unit
    # 153 (verses), not 158 (occurrences), even though the form posted 999.
    assert_equal 153, feature.saved_actual_count
    assert_equal 153, feature.expected_count
  end

  test "create saves the description entered in the dialog" do
    DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
      post features_path, params: feature_params(unit: "occurrences", description: "Peter across the NT")
    end

    assert_equal "Peter across the NT", SavedFeature.order(:id).last.description
  end

  test "new dialog offers a description field" do
    DiscoverQueryStore.stub(:fetch, discover_query) do
      DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
        DiscoveryScan.stub(:read_verses_cached, verse_result(153)) do
          get new_feature_path(edition: EDITION_ID, dq: "token")
        end
      end
    end

    assert_response :success
    assert_select "input[name=?]", "saved_feature[description]"
  end

  test "loading a saved verses feature reports the verse total" do
    feature = nil
    DiscoveryScan.stub(:read_verses_cached, verse_result(153)) do
      post features_path, params: feature_params(unit: "verses")
    end
    feature = SavedFeature.order(:id).last

    edition = EditionContext.new(EDITION_ID)
    row = nil
    DiscoveryScan.stub(:enabled_search_terms?, true) do
      DiscoveryScan.stub(:verses_cached?, true) do
        DiscoveryScan.stub(:read_verses_cached, verse_result(153)) do
          row = SavedFeatureCatalog.row_for(feature, edition, index: true)
        end
      end
    end

    assert_equal 153, row.count
    assert row.match
  end
end
