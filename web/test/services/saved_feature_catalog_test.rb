# frozen_string_literal: true

require "test_helper"

# Loading an existing saved feature must recompute its "Actual" count using the
# feature's own measure: occurrences features from the word-count rows, verses
# features from the verse scan total.
class SavedFeatureCatalogTest < ActiveSupport::TestCase
  WordRow = Struct.new(:count, :exclude, :overlap, keyword_init: true)

  EDITION_ID = "kjv_normalized"

  def edition
    @edition ||= begin
      double = Struct.new(:edition_id).new(EDITION_ID)
      def double.corpus_ready? = true
      def double.warm! = nil
      double
    end
  end

  def saved_feature(unit:, actual:)
    SavedFeature.new(
      name: "Peter",
      edition_id: EDITION_ID,
      scope_label: "All texts",
      unit: unit,
      mode: "word_count",
      expected_count: actual,
      saved_actual_count: actual,
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

  def with_stubs(pairs, &block)
    list = pairs.to_a
    return block.call if list.empty?

    name, value = list.first
    DiscoveryScan.stub(name, value) { with_stubs(list[1..], &block) }
  end

  test "occurrences feature counts matching tokens (index)" do
    rows = [WordRow.new(count: 158, exclude: false, overlap: false)]
    feature = saved_feature(unit: "occurrences", actual: 158)

    row = with_stubs(
      enabled_search_terms?: true,
      counts_cached?: true,
      read_counts_cached: rows
    ) { SavedFeatureCatalog.row_for(feature, edition, index: true) }

    assert_equal 158, row.count
    assert_equal "occurrences", row.unit
    assert row.match
  end

  test "verses feature counts matching verses, not tokens (index)" do
    feature = saved_feature(unit: "verses", actual: 153)

    row = with_stubs(
      enabled_search_terms?: true,
      verses_cached?: true,
      read_verses_cached: verse_result(153)
    ) { SavedFeatureCatalog.row_for(feature, edition, index: true) }

    assert_equal 153, row.count
    assert_equal "verses", row.unit
    assert row.match
  end

  test "verses feature reruns the verse scan when not cached (run)" do
    feature = saved_feature(unit: "verses", actual: 153)

    row = with_stubs(
      enabled_search_terms?: true,
      verses_cached?: false,
      valid_search_terms?: true,
      run_verses: verse_result(153)
    ) { SavedFeatureCatalog.row_for(feature, edition, index: false) }

    assert_equal 153, row.count
    assert row.match
  end

  test "the same query yields different totals per measure" do
    rows = [WordRow.new(count: 158, exclude: false, overlap: false)]

    occurrences_row = with_stubs(
      enabled_search_terms?: true,
      counts_cached?: true,
      read_counts_cached: rows
    ) { SavedFeatureCatalog.row_for(saved_feature(unit: "occurrences", actual: 158), edition, index: true) }

    verses_row = with_stubs(
      enabled_search_terms?: true,
      verses_cached?: true,
      read_verses_cached: verse_result(153)
    ) { SavedFeatureCatalog.row_for(saved_feature(unit: "verses", actual: 153), edition, index: true) }

    assert_equal 158, occurrences_row.count
    assert_equal 153, verses_row.count
  end
end
