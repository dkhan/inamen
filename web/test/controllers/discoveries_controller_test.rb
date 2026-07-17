# frozen_string_literal: true

require "test_helper"

class DiscoveriesControllerTest < ActionDispatch::IntegrationTest
  WordRow = Struct.new(:pattern, :case_sensitive, :count, :spellings, :exclude, :overlap, :wildcard, keyword_init: true)
  FakeEdition = Struct.new(:edition_id, :checksum_prefix, :corpus_ready, keyword_init: true) do
    def corpus_ready?
      corpus_ready
    end
  end

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
    run_verses_validate = nil
    cached = false

    DiscoverQueryStore.stub(:fetch, query) do
      DiscoverQueryStore.stub(:write, token) do
        DiscoveryScan.stub(:valid_search_terms?, ->(*) { raise "auto-scan should not validate saved feature criteria" }) do
          DiscoveryScan.stub(:counts_cached?, ->(*) { cached }) do
            DiscoveryScan.stub(:verses_cached?, ->(*) { false }) do
              DiscoveryScan.stub(:run_counts, ->(*, **kwargs) { run_counts_validate = kwargs[:validate]; cached = true; rows }) do
                DiscoveryScan.stub(:run_verses, ->(*, **kwargs) { run_verses_validate = kwargs[:validate]; nil }) do
                  get discoveries_path(edition: "kjv_normalized", dq: token, auto_scan: "1")
                end
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
    assert_equal false, run_verses_validate
  end

  test "scan reuses cached counts without validating phrases again" do
    query = {
      "mode" => "word_count",
      "search_selection" => { "submitted" => "1", "all_books" => "1" },
      "search_phrases" => {
        "0" => { "phrase" => "beginning" }
      }
    }
    token = "dq-token"
    ran_verses = false

    DiscoverQueryStore.stub(:fetch, query) do
      DiscoverQueryStore.stub(:write, token) do
        DiscoveryScan.stub(:valid_search_terms?, ->(*) { raise "cached scan should not validate" }) do
          DiscoveryScan.stub(:counts_cached?, true) do
            DiscoveryScan.stub(:run_verses, ->(*) { ran_verses = true; nil }) do
              post scan_discoveries_path(edition: "kjv_normalized", dq: token)
            end
          end
        end
      end
    end

    assert_response :redirect
    assert_includes response.location, "/discover"
    assert_includes response.location, "edition=kjv_normalized"
    assert_includes response.location, "query_terms=beginning"
    assert_equal true, ran_verses
  end

  test "scan runs divisible searches inline when corpus is ready" do
    fake = FakeEdition.new(edition_id: "test_edition", checksum_prefix: "abc123", corpus_ready: true)
    ran_scan = false

    EditionContext.stub(:all_ids, ["test_edition"]) do
      EditionContext.stub(:default_id, "test_edition") do
        EditionContext.stub(:new, fake) do
          DiscoveryScan.stub(:cached?, false) do
            DiscoveryScan.stub(:run, ->(*) { ran_scan = true; [] }) do
              post scan_discoveries_path(
                edition: "test_edition",
                mode: "divisible",
                divisible_by: "7",
                min_count: "7",
                search_selection: { submitted: "1", all_books: "1" }
              )
            end
          end
        end
      end
    end

    assert_response :redirect
    assert_includes response.location, "/discover"
    refute_includes response.location, "waiting=1"
    assert_equal true, ran_scan
  end

  test "divisible index renders rows from generic scan cache" do
    fake = FakeEdition.new(edition_id: "test_edition", checksum_prefix: "abc123", corpus_ready: true)
    rows = [
      DiscoveryScan::DivisibleRow.new(
        scope: "whole Bible",
        token_norm: "therefore",
        token_raw: "Therefore",
        count: 777,
        divisible_by: 7
      )
    ]

    EditionContext.stub(:all_ids, ["test_edition"]) do
      EditionContext.stub(:default_id, "test_edition") do
        EditionContext.stub(:new, fake) do
          DiscoveryScan.stub(:cached?, true) do
            DiscoveryScan.stub(:read_cached, rows) do
              get discoveries_path(
                edition: "test_edition",
                mode: "divisible",
                divisible_by: "7",
                min_count: "7"
              )
            end
          end
        end
      end
    end

    assert_response :success
    assert_select "td code", "therefore"
    assert_select "td", "777"
  end

  test "word count summary includes word matches verses chapters books and categorized scope" do
    fake = FakeEdition.new(edition_id: "test_edition", checksum_prefix: "abc123", corpus_ready: true)
    rows = [
      WordRow.new(pattern: "peter", case_sensitive: false, count: 153, spellings: {}, exclude: false, overlap: false)
    ]
    summary = Inamen::VerseMatchQuery::Summary.new(
      occurrences: 153,
      verses: 153,
      chapters: 21,
      books: 4,
      scope_label: "Gospels"
    )

    EditionContext.stub(:all_ids, ["test_edition"]) do
      EditionContext.stub(:default_id, "test_edition") do
        EditionContext.stub(:new, fake) do
          DiscoveryScan.stub(:counts_cached?, true) do
            DiscoveryScan.stub(:read_counts_cached, rows) do
              DiscoveryScan.stub(:word_count_summary, summary) do
                get discoveries_path(
                  edition: "test_edition",
                  mode: "word_count",
                  query_terms: "peter",
                  search_selection: {
                    submitted: "1",
                    colophons: "0",
                    superscriptions: "0",
                    books: %w[Matthew Mark Luke John]
                  }
                )
              end
            end
          end
        end
      end
    end

    assert_response :success
    assert_select ".discovery-verse-summary",
                  "Found 153 word match(es) in 153 Verse(s) in 21 Chapter(s) in 4 Book(s) within Gospels"
  end

  test "word count scan finds capitalized Cyrillic case-insensitively" do
    path = Rails.root.join("..", "data", "RUSSIAN_SYNODAL_77.txt").expand_path
    skip "Russian Synodal fixture missing" unless path.file?

    edition = Edition.find_or_create_by!(short_name: "russian_synodal_77") do |record|
      record.name = "Russian Synodal 77"
      record.corpus_type = "bible"
      record.source_path = path.to_s
      record.source_filename = path.basename.to_s
      record.source_checksum = Digest::SHA256.file(path).hexdigest
      record.byte_size = path.size
      record.imported_at = Time.current
    end
    edition.update!(
      source_path: path.to_s,
      source_filename: path.basename.to_s,
      source_checksum: Digest::SHA256.file(path).hexdigest,
      byte_size: path.size,
      metadata: edition.metadata.to_h.merge("language" => "ru")
    )

    scan_payload = {
      edition: "russian_synodal_77",
      mode: "word_count",
      search_selection: { submitted: "1", all_books: "1", colophons: "1", superscriptions: "1" },
      search_phrases: { "0" => { phrase: "Святой" } }
    }

    scan_params = DiscoveryScan.normalize(scan_payload)
    edition_context = EditionContext.new("russian_synodal_77")
    assert DiscoveryScan.valid_search_terms?(edition_context, scan_params.query_terms)

    rows = DiscoveryScan.compute_word_count_rows(edition_context, scan_params)
    assert_equal 41, rows.find { |row| row.pattern == "Святой" }&.count
  end
end
