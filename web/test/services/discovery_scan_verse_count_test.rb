# frozen_string_literal: true

require "test_helper"

class DiscoveryScanVerseCountTest < ActiveSupport::TestCase
  test "verse_count_total reads the verse total from the summary" do
    summary = Inamen::VerseMatchQuery::Summary.new(
      occurrences: 158, verses: 153, chapters: 40, books: 20, scope_label: "All texts"
    )
    result = Inamen::VerseMatchQuery::Result.new(summary: summary, verses: [], hits: [])

    assert_equal 153, DiscoveryScan.verse_count_total(result)
  end

  test "verse_count_total is zero when there is no verse result" do
    assert_equal 0, DiscoveryScan.verse_count_total(nil)
  end
end
