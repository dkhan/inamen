# frozen_string_literal: true

module DiscoverState
  extend ActiveSupport::Concern

  DISCOVER_QUERY_ID_KEY = :discover_query_id
  LEGACY_DISCOVER_QUERY_KEY = :discover_query

  included do
    helper_method :discover_path_with_state, :stored_discover_query, :use_discover_query_token_in_urls?,
                  :merge_fishermen_preset_excludes?
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

    from_feature = stored["from_feature"]
    from_feature.present? && Inamen::FeatureDiscoverPresets.bulky_phrase_feature?(from_feature)
  end

  def merge_fishermen_preset_excludes?
    return true unless request.post? && action_name == "scan"
    return true if params[:search_phrases].blank?

    from_feature = params[:from_feature].presence || stored_discover_query&.dig("from_feature")
    return true unless Inamen::FeatureDiscoverPresets.bulky_phrase_feature?(from_feature)

    raw = discover_raw_search_phrases_param
    return true if Inamen::FeatureDiscoverPresets.raw_has_exclude_phrases?(raw)

    Inamen::FeatureDiscoverPresets.fishermen_preset_includes?(raw)
  end

  private

  def load_stored_discover_query
    token = params[:dq].presence || session[DISCOVER_QUERY_ID_KEY]
    adopt_discover_query_token!(token) if params[:dq].present?

    query = DiscoverQueryStore.fetch(token)
    return query if query.present?

    legacy = session[LEGACY_DISCOVER_QUERY_KEY]
    return nil if legacy.blank?

    store_discover_query!(legacy)
    DiscoverQueryStore.fetch(session[DISCOVER_QUERY_ID_KEY])
  end

  def discover_raw_search_phrases_param
    return nil unless params[:search_phrases].present?

    if params[:search_phrases].is_a?(ActionController::Parameters)
      params[:search_phrases].permit!.to_h
    else
      params[:search_phrases].to_h
    end
  end
end
