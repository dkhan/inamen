# frozen_string_literal: true

module DiscoveriesHelper
  VERSE_RESULTS_DISPLAY_LIMIT = Inamen::VerseMatchQuery::DISPLAY_LIMIT
  def discovery_mode_options(selected)
    options_for_select(
      [
        ["Word count", "word_count"],
        ["File stats", "file_stats"],
        ["Divisible by N", "divisible"],
        ["Equal occurrence count", "equal_count"]
      ],
      selected
    )
  end

  def discovery_file_stats_highlight
    params[:highlight].presence
  end

  def discovery_file_stats_row_class(row_key)
    highlight = discovery_file_stats_highlight
    return "" if highlight.blank?

    "row-highlight" if highlight.to_s == row_key.to_s
  end

  def discovery_match_by_options(selected)
    options_for_select(
      [
        ["Normalized word (sum all spellings)", "norm"],
        ["Spelling (matches divisibility list)", "spelling"]
      ],
      selected
    )
  end

  def discovery_selection_label(selection)
    selection.label
  end

  def discovery_book_checked?(selection, book)
    selection.books.include?(book)
  end

  def discovery_category_checked?(selection, books)
    return false if books.empty?

    books.all? { |book| selection.books.include?(book) }
  end

  def discovery_category_indeterminate?(selection, books)
    return false if books.empty?

    checked = books.count { |book| selection.books.include?(book) }
    checked.positive? && checked < books.length
  end

  def discovery_testament_checked?(selection, testament)
    books = testament == :ot ? Inamen::BookCategories.ot_books : Inamen::BookCategories.nt_books
    discovery_category_checked?(selection, books)
  end

  def discovery_testament_indeterminate?(selection, testament)
    books = testament == :ot ? Inamen::BookCategories.ot_books : Inamen::BookCategories.nt_books
    discovery_category_indeterminate?(selection, books)
  end

  def discovery_search_phrases(scan_params)
    discovery_search_phrase_rows(scan_params).map(&:last)
  end

  def discovery_search_phrase_rows(scan_params)
    hydrated = discover_search_phrases_hash
    if hydrated.present?
      return hydrated.sort_by { |key, _| key.to_i }.map { |index, row| [index, phrase_entry_from_row(row)] }
    end

    rows = discovery_search_phrase_entries(scan_params).each_with_index.map { |phrase, index| [index.to_s, phrase] }
    return rows if rows.any?

    [["0", empty_discovery_phrase_entry]]
  end

  def empty_discovery_phrase_entry
    DiscoveryScan::PhraseEntry.new(phrase: "", case_sensitive: false, exclude: false, disabled: false)
  end

  def discovery_scan_hidden_phrases(scan_params)
    discovery_search_phrase_entries(scan_params)
  end

  def discovery_search_phrase_entries(scan_params)
    hydrated = discover_search_phrases_hash
    if hydrated.present?
      DiscoveryScan.phrase_entries_from_params(hydrated)
    else
      DiscoveryScan.phrase_entries_from_query_terms(scan_params.query_terms)
    end
  end

  def discovery_scan_hidden_fields(scan_params)
    selection = scan_params.search_selection
    parts = [
      hidden_field_tag(:mode, scan_params.mode),
      hidden_field_tag(:divisible_by, scan_params.divisible_by),
      hidden_field_tag(:min_count, scan_params.min_count),
      hidden_field_tag(:min_group_size, scan_params.min_group_size),
      hidden_field_tag(:match_by, scan_params.match_by),
      hidden_field_tag(:query_terms, scan_params.query_terms)
    ]

    discovery_scan_hidden_phrases(scan_params).each_with_index do |phrase, index|
      parts << hidden_field_tag("search_phrases[#{index}][phrase]", phrase.phrase)
      parts << hidden_field_tag("search_phrases[#{index}][case_sensitive]", "1") if phrase.case_sensitive
      parts << hidden_field_tag("search_phrases[#{index}][exclude]", "1") if phrase.exclude
      parts << hidden_field_tag("search_phrases[#{index}][disabled]", "1") if phrase.disabled
    end

    unless selection.default?
      parts << hidden_field_tag("search_selection[submitted]", "1")
      parts << hidden_field_tag("search_selection[colophons]", "1") if selection.colophons
      parts << hidden_field_tag("search_selection[superscriptions]", "1") if selection.superscriptions
      if selection.books.sort == Inamen::BookCategories.all_books.sort
        parts << hidden_field_tag("search_selection[all_books]", "1")
      else
        selection.books.each { |book| parts << hidden_field_tag("search_selection[books][]", book) }
      end
    end

    safe_join(parts, "\n")
  end

  def discovery_verses_query(edition, scan_params)
    query = discovery_scan_query(edition, scan_params)
    if use_discover_query_token_in_urls?
      return query.merge(dq: session[:discover_query_id]).except(:search_phrases, :query_terms)
    end

    phrases = discovery_search_phrases_param_hash(scan_params)
    query[:search_phrases] = phrases if phrases.present?
    query
  end

  def discovery_search_phrases_param_hash(scan_params)
    raw = discover_search_phrases_hash
    return raw if raw.present?

    DiscoveryScan.phrase_entries_from_query_terms(scan_params.query_terms).map.with_index.to_h do |phrase, index|
      [
        index.to_s,
        {
          "phrase" => phrase.phrase,
          "case_sensitive" => phrase.case_sensitive ? "1" : "0",
          "exclude" => phrase.exclude ? "1" : "0",
          "disabled" => phrase.disabled ? "1" : "0"
        }.compact
      ]
    end
  end

  def discovery_scan_query(edition, scan_params)
    selection = scan_params.search_selection
    query = {
      edition: edition.edition_id,
      mode: scan_params.mode,
      divisible_by: scan_params.divisible_by,
      min_count: scan_params.min_count,
      min_group_size: scan_params.min_group_size,
      match_by: scan_params.match_by,
      query_terms: scan_params.query_terms
    }

    return query if selection.default?

    selection_query = {
      submitted: "1",
      colophons: selection.colophons ? "1" : "0",
      superscriptions: selection.superscriptions ? "1" : "0"
    }
    if selection.books.sort == Inamen::BookCategories.all_books.sort
      selection_query[:all_books] = "1"
    else
      selection_query[:books] = selection.books
    end
    query.merge(search_selection: selection_query)
  end

  def discovery_word_count_total(rows)
    DiscoveryScan.word_count_table_total(rows)
  end

  def discovery_word_count_spellings_label(spellings, limit: 8)
    return "—" if spellings.blank?

    pairs = spellings.sort_by { |raw, count| [-count, raw] }
    if pairs.size <= limit
      pairs.map { |raw, count| "<code>#{h(raw)}</code> (#{number_with_delimiter(count)})" }.join(", ").html_safe
    else
      preview = pairs.first(limit).map { |raw, count| "<code>#{h(raw)}</code> (#{number_with_delimiter(count)})" }.join(", ")
      "#{preview}, … (+#{pairs.size - limit} more)".html_safe
    end
  end

  def discovery_equal_count_words_label(words, match_by:, limit: 12)
    labels = words.map do |word|
      if match_by == "spelling"
        raw = word.token_raws.first
        raw == word.token_norm ? raw : "#{raw} (#{word.token_norm})"
      else
        word.token_norm
      end
    end

    if labels.size <= limit
      labels.map { |w| "<code>#{h(w)}</code>" }.join(", ").html_safe
    else
      preview = labels.first(limit).map { |w| "<code>#{h(w)}</code>" }.join(", ")
      "#{preview}, … (+#{labels.size - limit} more)".html_safe
    end
  end

  def discovery_verse_match_summary(summary)
    scope_label = format_discovery_scope_label(summary.scope_label)
    "Found #{number_with_delimiter(summary.occurrences)} Occurrence(s) in " \
      "#{number_with_delimiter(summary.verses)} Verse(s) in " \
      "#{number_with_delimiter(summary.chapters)} Chapter(s) in " \
      "#{number_with_delimiter(summary.books)} Book(s) within #{scope_label}"
  end

  def discovery_verse_reference(row)
    Inamen::VerseMatchQuery.format_reference(row.book, row.chapter, row.verse, row.bucket)
  end

  def discovery_scripture_chapter_path(edition, row)
    scripture_chapter_path(
      book: row.book,
      chapter: row.chapter,
      edition: edition.edition_id,
      highlight: row.verse,
      hi: row.highlight_indices.join(","),
      bucket: row.bucket
    )
  end

  def discovery_verse_row_html(row)
    row.html_excerpt.presence || ""
  end

  def discovery_verse_row_details(row)
    row.details || {}
  end

  def discovery_verse_results_rows(verse_result)
    verse_result.verses.first(VERSE_RESULTS_DISPLAY_LIMIT)
  end

  def discovery_verse_results_truncated?(verse_result)
    verse_result.verses.length > VERSE_RESULTS_DISPLAY_LIMIT
  end

  def discovery_verse_results_display_limit
    VERSE_RESULTS_DISPLAY_LIMIT
  end

  def phrase_entry_from_row(row)
    entry = row.respond_to?(:symbolize_keys) ? row.symbolize_keys : row
    DiscoveryScan::PhraseEntry.new(
      phrase: entry[:phrase].to_s,
      case_sensitive: ActiveModel::Type::Boolean.new.cast(entry[:case_sensitive]),
      exclude: ActiveModel::Type::Boolean.new.cast(entry[:exclude]),
      disabled: ActiveModel::Type::Boolean.new.cast(entry[:disabled])
    )
  end

  def discover_search_phrases_hash(raw_phrases = nil)
    raw = if raw_phrases.present?
            raw_phrases.is_a?(ActionController::Parameters) ? raw_phrases.permit!.to_h : raw_phrases.to_h
          elsif params[:search_phrases].present?
            params[:search_phrases].permit!.to_h
          elsif stored_discover_query&.dig("search_phrases").present?
            stored_discover_query["search_phrases"]
          end
    raw || {}
  end

  private

  def format_discovery_scope_label(label)
    case label.to_s
    when "whole Bible"
      "Entire Bible"
    when "New Testament"
      "New Testament"
    when "Old Testament"
      "Old Testament"
    else
      label
    end
  end
end
