# frozen_string_literal: true

module ApplicationHelper
  def edition_options(selected_id)
    options_for_select(
      EditionContext.all_ids.map { |id| [id, id] },
      selected_id
    )
  end

  def number_research_link(number, label: nil, class_name: "number-link")
    value = number.to_i
    return label || number if value <= 0

    link_to(label || number_with_delimiter(value), number_path(value), class: class_name)
  end
end
