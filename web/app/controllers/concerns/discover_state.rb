# frozen_string_literal: true

module DiscoverState
  extend ActiveSupport::Concern

  DISCOVER_QUERY_ID_KEY = :discover_query_id
  LEGACY_DISCOVER_QUERY_KEY = :discover_query
  DISCOVER_SERVER_EPOCH_KEY = :discover_server_epoch

  included do
    helper_method :discover_path_with_state, :stored_discover_query, :use_discover_query_token_in_urls?,
                  :merge_fishermen_preset_excludes?
  end

  def reset_discover_query_if_server_restarted!
    current = discover_server_epoch
    return if session[DISCOVER_SERVER_EPOCH_KEY] == current

    token = session[DISCOVER_QUERY_ID_KEY].presence || params[:dq].presence
    DiscoverQueryStore.delete(token)
    session.delete(DISCOVER_QUERY_ID_KEY)
    session.delete(LEGACY_DISCOVER_QUERY_KEY)
    session[DISCOVER_SERVER_EPOCH_KEY] = current
    @discover_query_fresh = true
    remove_instance_variable(:@stored_discover_query) if defined?(@stored_discover_query)
    @stored_discover_query = nil
  end

  def store_discover_query!(query)
    token = session[DISCOVER_QUERY_ID_KEY]
    session[DISCOVER_QUERY_ID_KEY] = DiscoverQueryStore.write(token, query)
    session.delete(LEGACY_DISCOVER_QUERY_KEY)
    remove_instance_variable(:@stored_discover_query) if defined?(@stored_discover_query)
  end

  def stored_discover_query
    return @stored_discover_query if defined?(@stored_discover_query)

    @stored_discover_query = load_stored_discover_query
  end

  def discover_path_with_state
    discoveries_path(discover_query_params)
  end

  def discover_query_params
    stored = stored_discover_query
    return { edition: current_edition_id } if stored.blank?

    if use_discover_query_token_in_urls?
      return discover_query_url_params(stored).merge(
        edition: current_edition_id,
        dq: session[DISCOVER_QUERY_ID_KEY]
      )
    end

    stored.symbolize_keys.merge(edition: current_edition_id).except(:query_terms)
  end

  def discover_query_url_params(stored)
    stored = stored.deep_symbolize_keys
    stored.slice(
      :mode, :divisible_by, :min_count, :min_group_size, :match_by, :search_selection
    )
  end

  def adopt_discover_query_token!(token)
    return if token.blank?

    session[DISCOVER_QUERY_ID_KEY] = token
    session.delete(LEGACY_DISCOVER_QUERY_KEY)
    remove_instance_variable(:@stored_discover_query) if defined?(@stored_discover_query)
  end

  def use_discover_query_token_in_urls?
    return false if session[DISCOVER_QUERY_ID_KEY].blank?

    stored = stored_discover_query
    return false if stored.blank?

    phrases = stored["search_phrases"]
    return true if phrases.is_a?(Hash) && Inamen::FeatureDiscoverPresets.raw_has_exclude_phrases?(phrases)

    phrases.is_a?(Hash) && phrases.length > 4
  end

  def merge_fishermen_preset_excludes?
    false
  end

  private

  def load_stored_discover_query
    return nil if @discover_query_fresh

    token = params[:dq].presence || session[DISCOVER_QUERY_ID_KEY]
    adopt_discover_query_token!(token) if params[:dq].present?

    query = DiscoverQueryStore.fetch(token)
    return query if query.present?

    legacy = session[LEGACY_DISCOVER_QUERY_KEY]
    return nil if legacy.blank?

    store_discover_query!(legacy)
    DiscoverQueryStore.fetch(session[DISCOVER_QUERY_ID_KEY])
  end

  def discover_server_epoch
    Rails.application.config.discover_server_epoch
  end

  def discover_raw_search_phrases_param
    return nil unless params[:search_phrases].present?

    if params[:search_phrases].is_a?(ActionController::Parameters)
      params[:search_phrases].permit!.to_h
    else
      params[:search_phrases].to_h
    end
  end

  # Prefer URL/form phrases over session so a fishermen feature link rehydrates
  # antimentions even when the stored query was previously simplified.
  def fishermen_merge_raw_search_phrases
    if request.post? && action_name == "scan" && params[:search_phrases].present?
      discover_raw_search_phrases_param
    elsif params[:search_phrases].present?
      discover_raw_search_phrases_param
    else
      stored_discover_query&.dig("search_phrases")
    end
  end
end
