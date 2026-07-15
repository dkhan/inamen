# frozen_string_literal: true

require "test_helper"

class DiscoveriesControllerTest < ActionDispatch::IntegrationTest
  WordRow = Struct.new(:pattern, :case_sensitive, :count, :spellings, :exclude, :overlap, keyword_init: true)

  test "dq auto scan loads saved search criteria and runs on first click" do
    query = {
      "mode" => "word_count",
      "search_selection" => { "submitted" => "1", "all_books" => "1", "colophons" => "1" },
      "search_phrases" => {
        "0" => { "phrase" => "beginning" },
        "1" => { "phrase" => "Amen", "case_sensitive" => "1" }
      }
    }
    token = "dq-token"
    rows = [
      WordRow.new(pattern: "beginning", case_sensitive: false, count: 106, spellings: {}, exclude: false, overlap: false),
      WordRow.new(pattern: "Amen", case_sensitive: true, count: 77, spellings: {}, exclude: false, overlap: false)
    ]
    run_counts_validate = nil
    enqueue_validate = nil
    cached = false

    DiscoverQueryStore.stub(:fetch, query) do
      DiscoverQueryStore.stub(:write, token) do
        DiscoveryScan.stub(:valid_search_terms?, ->(*) { raise "auto-scan should not validate saved feature criteria" }) do
          DiscoveryScan.stub(:counts_cached?, ->(*) { cached }) do
            DiscoveryScan.stub(:run_counts, ->(*, **kwargs) { run_counts_validate = kwargs[:validate]; cached = true; rows }) do
              DiscoveryScan.stub(:enqueue_verses!, ->(*, **kwargs) { enqueue_validate = kwargs[:validate]; nil }) do
                get discoveries_path(edition: "kjv_normalized", dq: token, auto_scan: "1")
              end
            end
          end
        end
      end
    end

    assert_response :success
    assert_select "input[name=?][value=?]", "search_phrases[0][phrase]", "beginning"
    assert_select "input[name=?][value=?]", "search_phrases[1][phrase]", "Amen"
    assert_select "input[name=?][checked]", "search_phrases[1][case_sensitive]"
    assert_equal false, run_counts_validate
    assert_equal false, enqueue_validate
  end
end
