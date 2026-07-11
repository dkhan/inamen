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
    if SavedFeature.url_id?(feature_id)
      saved_feature = SavedFeature.find_by_url_id!(feature_id)
      store_query = {
        "mode" => saved_feature.mode,
        "search_selection" => saved_feature.search_selection,
        "search_phrases" => saved_feature.search_phrases
      }
      token = DiscoverQueryStore.write(session[DiscoverState::DISCOVER_QUERY_ID_KEY], store_query)
      session[DiscoverState::DISCOVER_QUERY_ID_KEY] = token
      return discoveries_path(edition: saved_feature.edition_id, dq: token, auto_scan: "1")
    end

    query = FeatureDiscoverLink.query_for(feature_id, edition_id: edition)
    return nil unless query

    discoveries_path(query)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def feature_discover_name(feature_id)
    if SavedFeature.url_id?(feature_id)
      return SavedFeature.find_by_url_id!(feature_id).name
    end

    Inamen::Features.fetch(feature_id).name
  rescue ArgumentError, ActiveRecord::RecordNotFound
    feature_id.to_s.tr("_", " ")
  end

  def feature_save_path(actual_count:, edition:)
    new_feature_path(edition: edition, actual_count: actual_count)
  end

  def saved_feature_row?(row)
    SavedFeature.url_id?(row.id)
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
