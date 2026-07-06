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

  def discovery_scope_options(selected)
    options_for_select(
      DiscoveryScan::SCOPES.map { |s| [s.tr("_", " "), s] },
      selected
    )
  end

  def discovery_bucket_options(selected)
    labels = {
      "default" => "Scannable (verse text + headings + colophons)",
      "verse_text" => "Verse text only",
      "psalm_heading" => "Psalm headings",
      "colophon" => "Colophons"
    }
    options_for_select(
      DiscoveryScan::BUCKETS.map { |b| [labels.fetch(b, b), b] },
      selected
    )
  end

  def discovery_scan_query(edition, scan_params)
    {
      edition: edition.edition_id,
      mode: scan_params.mode,
      divisible_by: scan_params.divisible_by,
      scope: scan_params.scope,
      bucket: scan_params.bucket,
      min_count: scan_params.min_count,
      min_group_size: scan_params.min_group_size,
      match_by: scan_params.match_by,
      query_terms: scan_params.query_terms
    }
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
