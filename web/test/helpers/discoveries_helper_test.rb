# frozen_string_literal: true

require "test_helper"

class DiscoveriesHelperTest < ActionView::TestCase
  include ApplicationHelper

  def word_rows(count, exclusions: [])
    rows = [
      DiscoveryScan::WordCountRow.new(
        pattern: "include",
        case_sensitive: false,
        count: count,
        wildcard: false,
        scope: nil,
        spellings: { "include" => count },
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

  test "word count total uses adjusted rows even when verse summary occurrences differ" do
    rows = word_rows(10, exclusions: [["exclude", 3]])
    summary = Inamen::VerseMatchQuery::Summary.new(
      occurrences: 99,
      verses: 5,
      chapters: 2,
      books: 1,
      scope_label: "All texts"
    )
    scan_params = DiscoveryScan::Params.new(
      mode: "word_count",
      search_selection: Inamen::SearchSelection.default,
      query_terms: "include"
    )

    assert_equal 7, discovery_word_count_total(rows, summary: summary)

    label = discovery_word_match_summary(rows, scan_params, summary: summary)
    assert_includes label, "7"
    refute_includes label, "99 word"
    assert_includes label, "5"
  end
end
