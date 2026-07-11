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
    query = FeatureDiscoverLink.query_for(feature_id, edition_id: edition)
    return nil unless query

    discoveries_path(query)
  end

  def feature_discover_name(feature_id)
    Inamen::Features.fetch(feature_id).name
  rescue ArgumentError
    feature_id.to_s.tr("_", " ")
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
end
