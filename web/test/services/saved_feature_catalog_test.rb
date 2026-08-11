# frozen_string_literal: true

require "test_helper"

# SavedFeatureCatalog verifies a feature against any edition and persists the
# per-edition result in feature_editions, generically (occurrences vs verses),
# without touching the feature's expected value or original edition.
class SavedFeatureCatalogTest < ActiveSupport::TestCase
  def edition(id, language: "en")
    double = Struct.new(:edition_id, :language).new(id, language)
    def double.corpus_ready? = true
    def double.warm! = nil
    double
  end

  def saved_feature(unit: "occurrences", expected: 158, original: "kjv_normalized", language: "en")
    SavedFeature.create!(
      name: "Peter",
      original_edition_id: original,
      language: language,
      scope_label: "All texts",
      unit: unit,
      mode: "word_count",
      expected_count: expected,
      search_selection: { "submitted" => "1" },
      search_phrases: { "0" => { "phrase" => "peter" } }
    )
  end

  def verse_result(verses)
    summary = Inamen::VerseMatchQuery::Summary.new(
      occurrences: 158, verses: verses, chapters: 40, books: 20, scope_label: "All texts"
    )
    Inamen::VerseMatchQuery::Result.new(summary: summary, verses: [], hits: [])
  end

  def word_rows(count, exclusions: [])
    rows = [
      DiscoveryScan::WordCountRow.new(
        pattern: "peter",
        case_sensitive: false,
        count: count,
        wildcard: false,
        scope: nil,
        spellings: { "peter" => count },
        exclude: false,
        overlap: false
      )
    ]

    exclusions.each do |pattern, exclusion_count|
      rows << DiscoveryScan::WordCountRow.new(
        pattern: pattern,
        case_sensitive: false,
        count: exclusion_count,
        wildcard: false,
        scope: nil,
        spellings: { pattern => exclusion_count },
        exclude: true,
        overlap: false
      )
    end

    rows
  end

  def with_stubs(pairs, &block)
    list = pairs.to_a
    return block.call if list.empty?

    name, value = list.first
    DiscoveryScan.stub(name, value) { with_stubs(list[1..], &block) }
  end

  test "occurrences feature is verified and persisted for an edition" do
    feature = saved_feature(unit: "occurrences", expected: 158)

    record = with_stubs(enabled_search_terms?: true, valid_search_terms?: true, run_counts: word_rows(158)) do
      SavedFeatureCatalog.verified_edition(feature, edition("kjv_normalized"))
    end

    assert record.persisted?
    assert_equal 158, record.actual
    assert record.status_match?
    assert record.processing_verified?
    assert_equal "kjv_normalized", record.edition_id
  end

  test "verses feature counts matching verses, not tokens" do
    feature = saved_feature(unit: "verses", expected: 153)

    record = with_stubs(enabled_search_terms?: true, valid_search_terms?: true, run_verses: verse_result(153)) do
      SavedFeatureCatalog.verified_edition(feature, edition("kjv_normalized"))
    end

    assert_equal 153, record.actual
    assert record.status_match?
  end

  test "a mismatch is recorded as MISS" do
    feature = saved_feature(unit: "occurrences", expected: 999)

    record = with_stubs(enabled_search_terms?: true, valid_search_terms?: true, run_counts: word_rows(158)) do
      SavedFeatureCatalog.verified_edition(feature, edition("kjv_normalized"))
    end

    assert_equal 158, record.actual
    assert record.status_miss?
    refute record.match?
  end

  test "cached results are reused without recomputing" do
    feature = saved_feature(unit: "occurrences", expected: 158)

    with_stubs(enabled_search_terms?: true, valid_search_terms?: true, run_counts: word_rows(158)) do
      SavedFeatureCatalog.verified_edition(feature, edition("kjv_normalized"))
    end

    # No stubs here: if it recomputed it would hit the (stubless) scan path; it
    # must instead return the cached FeatureEdition.
    assert_no_difference "FeatureEdition.count" do
      record = SavedFeatureCatalog.verified_edition(feature, edition("kjv_normalized"))
      assert_equal 158, record.actual
    end
  end

  test "concurrent verification reuses row created after initial lookup" do
    feature = saved_feature(unit: "occurrences", expected: 158)
    existing = FeatureEdition.create!(
      feature_id: feature.id,
      edition_id: "kjv_normalized",
      actual: 158,
      status: FeatureEdition::STATUS_MATCH,
      processing_state: :verified,
      verified_at: Time.current
    )
    duplicate = FeatureEdition.new(feature_id: feature.id, edition_id: "kjv_normalized")

    with_stubs(enabled_search_terms?: true, valid_search_terms?: true, run_counts: word_rows(158)) do
      FeatureEdition.stub(:find_or_initialize_by, duplicate) do
        record = SavedFeatureCatalog.verified_edition(feature, edition("kjv_normalized"), force: true)
        assert_equal existing, record
      end
    end
  end

  test "verifying against a different edition adds a separate record, no duplicates" do
    feature = saved_feature(unit: "occurrences", expected: 158, original: "kjv_normalized")

    with_stubs(enabled_search_terms?: true, valid_search_terms?: true, run_counts: word_rows(158)) do
      SavedFeatureCatalog.verified_edition(feature, edition("kjv_normalized"))
      SavedFeatureCatalog.verified_edition(feature, edition("concord"))
      SavedFeatureCatalog.verified_edition(feature, edition("concord")) # again → no dupe
    end

    assert_equal 2, feature.feature_editions.count
    assert_equal %w[concord kjv_normalized], feature.feature_editions.pluck(:edition_id).sort
  end

  test "rows_for_edition only includes features for the edition language" do
    english = saved_feature(language: "en")
    russian = saved_feature(original: "russian_synodal_77", language: "ru")
    russian.feature_editions.create!(
      edition_id: "russian_synodal_77",
      actual: 158,
      status: FeatureEdition::STATUS_MATCH,
      processing_state: :verified,
      verified_at: Time.current
    )

    rows = SavedFeatureCatalog.rows_for_edition(edition("russian_synodal_77", language: "ru"))

    assert_equal [russian.url_id], rows.map(&:id)
    assert_nil english.feature_editions.find_by(edition_id: "russian_synodal_77")
  end

  test "verification never changes the feature's expected value or original edition" do
    feature = saved_feature(unit: "occurrences", expected: 158, original: "kjv_normalized")

    with_stubs(enabled_search_terms?: true, valid_search_terms?: true, run_counts: word_rows(42)) do
      SavedFeatureCatalog.verified_edition(feature, edition("concord"))
    end

    feature.reload
    assert_equal 158, feature.expected_count
    assert_equal "kjv_normalized", feature.original_edition_id
    assert_equal 42, feature.feature_editions.find_by(edition_id: "concord").actual
  end

  test "occurrences feature uses adjusted word-count rows instead of verse summary occurrences" do
    feature = saved_feature(unit: "occurrences", expected: 155)

    with_stubs(
      enabled_search_terms?: true,
      valid_search_terms?: true,
      run_counts: word_rows(158, exclusions: [["excluded phrase", 3]]),
      run_verses: verse_result(153)
    ) do
      record = SavedFeatureCatalog.verified_edition(feature, edition("concord"))

      assert_equal 155, record.actual
      assert record.status_match?
    end
  end
end
