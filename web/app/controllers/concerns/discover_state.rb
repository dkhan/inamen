# frozen_string_literal: true

module DiscoverState
  extend ActiveSupport::Concern

  included do
    helper_method :discover_path_with_state
  end

  def store_discover_query!(query)
    session[:discover_query] = query.deep_stringify_keys
  end

  def discover_path_with_state
    discoveries_path(discover_query_params)
  end

  def discover_query_params
    stored = session[:discover_query]
    return { edition: current_edition_id } if stored.blank?

    stored.symbolize_keys.merge(edition: current_edition_id)
  end
end
