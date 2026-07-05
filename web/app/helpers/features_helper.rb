# frozen_string_literal: true

module FeaturesHelper
  def format_feature_count(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def feature_match_badge(match)
    tag.span(match ? "match" : "miss", class: "badge #{match ? 'badge-pass' : 'badge-fail'}")
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
