# frozen_string_literal: true

module DiscoveriesHelper
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
      divisible_by: scan_params.divisible_by,
      scope: scan_params.scope,
      bucket: scan_params.bucket,
      min_count: scan_params.min_count
    }
  end
end
