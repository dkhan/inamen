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

  def feature_params(unit:, description: nil, feature_type: "bible", edition_id: EDITION_ID, language: nil, expected: nil)
    saved_feature = {
      name: "Peter (#{unit})",
      original_edition_id: edition_id,
      feature_type: feature_type,
      scope_label: "All texts",
      unit: unit,
      mode: "word_count",
      expected_count: (expected || (unit == "verses" ? 153 : 158)).to_s,
      search_selection_json: { "submitted" => "1" }.to_json,
      search_phrases_json: { "0" => { "phrase" => "peter" } }.to_json
    }
    saved_feature[:description] = description if description
    saved_feature[:language] = language if language

    { edition: edition_id, saved_feature: saved_feature }
  end

  def ensure_russian_edition
    path = Rails.root.join("..", "data", "RUSSIAN_SYNODAL_77.txt").expand_path
    path = Rails.root.join("..", "data", "KJV.txt").expand_path unless path.file?
    edition = Edition.find_or_create_by!(short_name: "russian_synodal_77") do |edition|
      edition.name = "Russian Synodal 77"
      edition.corpus_type = "bible"
      edition.source_path = path.to_s
      edition.source_filename = path.basename.to_s
      edition.source_checksum = Digest::SHA256.file(path).hexdigest
      edition.byte_size = path.size
      edition.imported_at = Time.current
    end
    edition.update!(metadata: edition.metadata.to_h.merge("language" => "ru"))
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
    # Actual is read-only; Expected defaults from the scan but can be edited.
    assert_select "input[name=?][readonly]", "saved_feature[actual]"
    assert_select "input[name=?][readonly]", "saved_feature[expected_count]", false
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
    # 153 (verses), not 158 (occurrences).
    assert_equal 153, feature.expected_count
    assert_equal 153, feature.feature_editions.find_by(edition_id: EDITION_ID).actual
  end

  test "create preserves an edited expected count while storing computed actual" do
    DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
      post features_path, params: feature_params(unit: "occurrences", expected: 777)
    end

    feature = SavedFeature.order(:id).last
    record = feature.feature_editions.find_by(edition_id: EDITION_ID)

    assert_equal 777, feature.expected_count
    assert_equal 158, record.actual
    assert record.status_miss?
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

  test "new and create mark features with the source edition language" do
    ensure_russian_edition

    DiscoverQueryStore.stub(:fetch, discover_query) do
      DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
        DiscoveryScan.stub(:read_verses_cached, verse_result(153)) do
          get new_feature_path(edition: "russian_synodal_77", dq: "token")
        end
      end
    end

    assert_response :success
    assert_select "select[name=?] option[value=?][selected]", "saved_feature[language]", "ru"

    DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
      post features_path, params: feature_params(unit: "occurrences", edition_id: "russian_synodal_77")
    end

    assert_equal "ru", SavedFeature.order(:id).last.language
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

  test "feature show edition status links open Discover for that edition and saved search" do
    DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
      post features_path, params: feature_params(unit: "occurrences")
    end
    feature = SavedFeature.order(:id).last
    FeatureEdition.create!(
      feature_id: feature.id,
      edition_id: "concord",
      actual: 140,
      status: FeatureEdition::STATUS_MISS,
      processing_state: :verified,
      verified_at: Time.current
    )

    get feature_path(feature.url_id, edition: EDITION_ID)

    assert_response :success
    assert_select "a.feature-discover-status-link[href*='edition=concord'][href*='dq='][href*='auto_scan=1']",
                  text: /miss/i
  end

  test "feature type and language are stored on create and editable on update" do
    DiscoveryScan.stub(:read_counts_cached, word_rows(158)) do
      post features_path, params: feature_params(unit: "occurrences", feature_type: "general_text", language: "en")
    end
    feature = SavedFeature.order(:id).last
    assert_equal "general_text", feature.feature_type
    assert_equal "en", feature.language

    patch feature_path(feature.url_id, edition: EDITION_ID),
          params: { saved_feature: { feature_type: "both", language: "ru" } }
    assert_equal "both", feature.reload.feature_type
    assert_equal "ru", feature.language
  end

  test "feature show displays categorized scope in stats and details" do
    feature = SavedFeature.create!(
      name: "Gospel search",
      original_edition_id: EDITION_ID,
      scope_label: "4 books",
      unit: SavedFeature::UNIT_OCCURRENCES,
      mode: "word_count",
      expected_count: 153,
      search_selection: {
        "submitted" => "1",
        "colophons" => "0",
        "superscriptions" => "0",
        "books" => %w[Matthew Mark Luke John]
      },
      search_phrases: { "0" => { "phrase" => "peter" } },
      details: ["peter"]
    )
    feature.feature_editions.create!(
      edition_id: EDITION_ID,
      actual: 153,
      status: FeatureEdition::STATUS_MATCH,
      processing_state: :verified,
      verified_at: Time.current
    )

    get feature_path(feature.url_id, edition: EDITION_ID)

    assert_response :success
    assert_select "dt", "Scope"
    assert_select "dd", "Gospels"
    assert_select ".detail-list li code", "Scope: Gospels"
  end
end
