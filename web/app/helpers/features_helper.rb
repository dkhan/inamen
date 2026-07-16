# frozen_string_literal: true

module FeaturesHelper
  def format_feature_count(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def feature_match_badge(match, discoverable: false)
    classes = ["badge", match ? "badge-pass" : "badge-fail"]
    classes << (discoverable ? "badge-discoverable" : "badge-static")
    tag.span(match ? "match" : "miss", class: classes.join(" "))
  end

  def feature_discover_status_link(feature_id, match:, edition:)
    path = feature_discover_path_for(feature_id, edition: edition)
    discoverable = path.present?
    badge = feature_match_badge(match, discoverable: discoverable)
    return badge unless path

    link_to(path, class: "feature-discover-status-link", title: "Explore in Discover") do
      badge
    end
  end

  def feature_discover_pending_link(feature_id, edition:)
    path = feature_discover_path_for(feature_id, edition: edition)
    discoverable = path.present?
    badge = tag.span(
      "pending",
      class: ["badge", "badge-pending", discoverable ? "badge-discoverable" : "badge-static"].join(" ")
    )
    return badge unless path

    link_to(path, class: "feature-discover-status-link", title: "Explore in Discover") do
      badge
    end
  end

  def feature_discover_path_for(feature_id, edition:)
    return unless SavedFeature.url_id?(feature_id)

    saved_feature = SavedFeature.find_by_url_id!(feature_id)
    if saved_feature.file_stats?
      highlight = saved_feature.characters? ? "file_characters" : "combined_total"
      return discoveries_path(edition: edition, mode: "file_stats", highlight: highlight)
    end

    # Load only the generic search criteria into Discover. The resulting scan
    # carries no feature identity, so editing/rerunning never touches the
    # original saved feature.
    store_query = {
      "mode" => saved_feature.mode,
      "search_selection" => saved_feature.search_selection,
      "search_phrases" => saved_feature.search_phrases,
      "from_feature" => saved_feature.url_id
    }
    token = DiscoverQueryStore.write(nil, store_query)
    discoveries_path(edition: edition, dq: token, feature: saved_feature.url_id, auto_scan: "1")
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def feature_discover_name(feature_id)
    SavedFeature.find_by_url_id!(feature_id).name
  rescue ActiveRecord::RecordNotFound
    feature_id.to_s.tr("_", " ")
  end

  def feature_save_path(actual_count:, edition:)
    new_feature_path(edition: edition, actual_count: actual_count)
  end

  def feature_measure_options(selected = nil, units: SavedFeature::WORD_COUNT_UNITS)
    options_for_select(units.map { |unit| [unit.capitalize, unit] }, selected)
  end

  FEATURE_TYPE_LABELS = {
    "bible" => "Bible", "general_text" => "General text", "both" => "Both"
  }.freeze

  def feature_type_options(selected = nil)
    options = SavedFeature.feature_types.keys.map { |key| [feature_type_label(key), key] }
    options_for_select(options, selected)
  end

  def feature_type_label(value)
    FEATURE_TYPE_LABELS.fetch(value.to_s, value.to_s.tr("_", " ").capitalize)
  end

  def saved_feature_row?(row)
    true
  end

  def saved_feature_actions(row, edition:)
    return unless saved_feature_row?(row)

    safe_join(
      [
        link_to(
          "✎",
          edit_feature_path(row.id, edition: edition),
          class: "feature-icon-button",
          title: "Edit",
          aria: { label: "Edit #{row.name}" }
        ),
        button_to(
          "×",
          feature_path(row.id, edition: edition),
          method: :delete,
          class: "feature-icon-button",
          form: { class: "feature-icon-form" },
          title: "Delete",
          aria: { label: "Delete #{row.name}" },
          data: { turbo_confirm: "Delete \"#{row.name}\"?" }
        )
      ],
      " "
    )
  end

  def edition_options(selected_id)
    options_for_select(
      EditionContext.all_ids.map { |id| [id, id] },
      selected_id
    )
  end

  def feature_kjvcode_link(url)
    return if url.blank?

    link_to "KJV Code", url, class: "inline-link", target: "_blank", rel: "noopener noreferrer"
  end

  def format_feature_notes(text)
    Inamen::NoteFormatter.render(text).html_safe
  end
end
