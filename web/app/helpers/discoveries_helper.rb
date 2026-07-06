# frozen_string_literal: true

module DiscoveriesHelper
  def discovery_mode_options(selected)
    options_for_select(
      [
        ["Word count", "word_count"],
        ["Divisible by N", "divisible"],
        ["Equal occurrence count", "equal_count"]
      ],
      selected
    )
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
    rows.sum(&:count)
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
end
