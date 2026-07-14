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

  def feature_params(unit:, description: nil, feature_type: "bible")
    saved_feature = {
      name: "Peter (#{unit})",
      original_edition_id: EDITION_ID,
      feature_type: feature_type,
      scope_label: "All texts",
      unit: unit,
      mode: "word_count",
      # Intentionally wrong value: the server must overwrite it from the cached
      # search results for the selected measure.
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
    assert_select "input[name=?][readonly]", "saved_feature[actual]"
    assert_select "input[name=?][readonly]", "saved_feature[expected_count]"
    # Feature type is a required selectable field.
    assert_select "select[name=?]", "saved_feature[feature_type]"
  end

  test "create saves the occurrences total for the occurrences measure" do
    DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
      assert_difference "SavedFeature.count", 1 do
        post features_path, params: feature_params(unit: "occurrences")
      end
    end

    feature = SavedFeature.order(:id).last
    assert_equal "occurrences", feature.unit
    assert_equal 158, feature.expected_count
    # The actual for the original edition is persisted as a FeatureEdition.
    record = feature.feature_editions.find_by(edition_id: EDITION_ID)
    assert_equal 158, record.actual
    assert record.status_match?
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
    assert_equal 153, feature.expected_count
    assert_equal 153, feature.feature_editions.find_by(edition_id: EDITION_ID).actual
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

  test "loading a saved verses feature reports the verse total from its FeatureEdition" do
    DiscoveryScan.stub(:read_verses_cached, verse_result(153)) do
      post features_path, params: feature_params(unit: "verses")
    end
    feature = SavedFeature.order(:id).last

    # The origin-edition FeatureEdition was persisted on create; row_for reuses it.
    row = SavedFeatureCatalog.row_for(feature, EditionContext.new(EDITION_ID))

    assert_equal 153, row.count
    assert row.match
  end

  test "features index verifies all saved features against the selected edition" do
    # A feature whose original edition is kjv_normalized, with no concord result yet.
    DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
      post features_path, params: feature_params(unit: "occurrences")
    end
    feature = SavedFeature.order(:id).last
    assert_nil feature.feature_editions.find_by(edition_id: "concord")

    rows = [DiscoveryScan::WordCountRow.new(pattern: "peter", case_sensitive: false, count: 140,
                                            wildcard: false, scope: "x", spellings: {}, exclude: false)]
    DiscoveryScan.stub(:enabled_search_terms?, true) do
      DiscoveryScan.stub(:valid_search_terms?, true) do
        DiscoveryScan.stub(:run_counts, rows) do
          get features_path(edition: "concord")
        end
      end
    end

    assert_response :success
    record = feature.feature_editions.find_by(edition_id: "concord")
    assert_not_nil record, "a FeatureEdition is created for the selected edition"
    assert_equal 140, record.actual
    # Expected value and original edition are untouched by cross-edition verification.
    assert_equal 158, feature.reload.expected_count
    assert_equal EDITION_ID, feature.original_edition_id
  end

  test "feature type is stored on create and editable on update" do
    DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
      post features_path, params: feature_params(unit: "occurrences", feature_type: "general_text")
    end
    feature = SavedFeature.order(:id).last
    assert_equal "general_text", feature.feature_type

    patch feature_path(feature.url_id, edition: EDITION_ID),
          params: { saved_feature: { feature_type: "both" } }
    assert_equal "both", feature.reload.feature_type
  end
end
