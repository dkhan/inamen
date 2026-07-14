# frozen_string_literal: true

require "test_helper"

# A saved word-count search with wildcard includes and overlapping exclusion
# phrases must report the same occurrence total everywhere — the Features table
# (index count), the Feature Show page (run count), and a fresh Discover scan —
# with each excluded base occurrence subtracted exactly once. Uses a real saved
# search's criteria; named around the generic behavior, not the feature.
class SavedSearchOccurrenceCountTest < ActiveSupport::TestCase
  EDITION_ID = "kjv_normalized"
  EXPECTED = 153

  SEARCH_SELECTION = {
    "submitted" => "1", "colophons" => "0", "superscriptions" => "0",
    "books" => %w[Matthew Mark Luke John]
  }.freeze

  SEARCH_PHRASES = {
    "0" => { "phrase" => "Peter*" },
    "1" => { "phrase" => "Thomas*" },
    "2" => { "phrase" => "Nathanael*" },
    "3" => { "phrase" => "James*" },
    "4" => { "phrase" => "John*" },
    "5" => { "exclude" => "1", "phrase" =>
      "ANTIMENTIONS OF JAMES (SON OF ZEBEDEE) | James the son of Alphaeus | James and Joses | " \
      "James the less | Judas the brother of James | Mary the mother of James | " \
      "Go shew these things unto James | had held their peace James answered | " \
      "went in with us unto James | he was seen of James then of all the | saw I none save James the | " \
      "And when James | certain came from James | James a servant of God | and brother of James" },
    "6" => { "exclude" => "1", "phrase" =>
      "ANTIMENTIONS OF JOHN (THE APOSTLE, SON OF ZEBEDEE) | John the Baptist | the same John had | " \
      "John to be baptized | But John forbad him | John was cast | disciples of John | " \
      "when John had heard | Go and shew John | multitudes concerning John | prophesied until John | " \
      "For John came neither | laid hold on John | For John said unto | John Baptist* | beheaded John | " \
      "baptism of John | John as a prophet | For John came unto you | John did baptize | John was clothed | " \
      "baptized of John | John was put in prison | It is John whom I beheaded | laid hold upon John | " \
      "For John had said unto Herod | Herod feared John | all men counted John | call his name John | " \
      "he shall be called John | His name is John | God came unto John | mused in their hearts of John | " \
      "John answered saying unto them all I indeed baptize | shut up John in prison | And John calling unto him | " \
      "and tell John what things | the people concerning John | messengers of John | John was risen | " \
      "John have I beheaded | as John also taught | prophets were until John | John was a prophet | " \
      "from God whose name was John | John bare witness | the record of John | " \
      "John answered them saying I baptize | John was baptizing | The next day John seeth | And John bare record | " \
      "next day after John stood | two which heard John speak | John also was baptizing | For John was not yet | " \
      "some of John’s disciples | And they came unto John | John answered and said A man can receive | " \
      "more disciples than John | Ye sent unto John | witness than that of John | John at first baptized | " \
      "John did no miracle | John spake of this man | John truly baptized | baptism which John | " \
      "John indeed baptized | John had first preached before | as John fulfilled his course | John’s baptism | " \
      "John verily baptized | Caiaphas and John and Alexander | John whose surname was" }
  }.freeze

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end

  def saved_feature
    SavedFeature.create!(
      name: "Overlapping-exclusion occurrence search",
      edition_id: EDITION_ID,
      scope_label: "4 books",
      unit: SavedFeature::UNIT_OCCURRENCES,
      mode: "word_count",
      expected_count: EXPECTED,
      saved_actual_count: EXPECTED,
      search_selection: SEARCH_SELECTION,
      search_phrases: SEARCH_PHRASES
    )
  end

  test "Discover recomputes the occurrence total with overlaps subtracted once" do
    edition = EditionContext.new(EDITION_ID)
    skip "corpus not available" unless edition.corpus_ready?

    rows = DiscoveryScan.compute_word_count_rows(edition, saved_feature.to_scan_params)
    assert_equal EXPECTED, DiscoveryScan.word_count_table_total(rows)
  end

  test "Features table, Feature Show, and Discover all report the matching total" do
    edition = EditionContext.new(EDITION_ID)
    skip "corpus not available" unless edition.corpus_ready?

    feature = saved_feature

    with_memory_cache do
      # Prime the shared counts cache the way a real request would, so the
      # Features-table index count reads the recomputed value (not a fallback).
      DiscoveryScan.run_counts(edition, feature.to_scan_params)

      index_row = SavedFeatureCatalog.row_for(feature, edition, index: true)  # Features table
      show_row  = SavedFeatureCatalog.row_for(feature, edition, index: false) # Feature Show
      discover_total = DiscoveryScan.word_count_table_total(
        DiscoveryScan.compute_word_count_rows(edition, feature.to_scan_params)
      )

      assert_equal EXPECTED, index_row.count
      assert_equal EXPECTED, show_row.count
      assert_equal EXPECTED, discover_total
      assert index_row.match, "Features table shows MATCH"
      assert show_row.match, "Feature Show shows MATCH"
      assert_equal feature.saved_actual_count, discover_total,
                   "loading into Discover reproduces the count used for matching"
    end
  end

  test "persisted phrases, scope, and options round-trip unchanged" do
    feature = saved_feature.reload

    assert_equal SEARCH_SELECTION, feature.search_selection
    assert_equal SEARCH_PHRASES, feature.search_phrases
    assert_equal "1", feature.search_phrases["5"]["exclude"]
    assert_equal "occurrences", feature.unit
  end
end
