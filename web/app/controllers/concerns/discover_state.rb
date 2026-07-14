# frozen_string_literal: true

module DiscoverState
  extend ActiveSupport::Concern

  DISCOVER_QUERY_ID_KEY = :discover_query_id
  LEGACY_DISCOVER_QUERY_KEY = :discover_query
  DISCOVER_SERVER_EPOCH_KEY = :discover_server_epoch

  included do
    helper_method :discover_path_with_state, :stored_discover_query, :use_discover_query_token_in_urls?
  end

  def reset_discover_query_if_server_restarted!
    current = discover_server_epoch
    return if session[DISCOVER_SERVER_EPOCH_KEY] == current

    DiscoverQueryStore.delete(session[DISCOVER_QUERY_ID_KEY]) if session[DISCOVER_QUERY_ID_KEY].present?
    session.delete(DISCOVER_QUERY_ID_KEY)
    session.delete(LEGACY_DISCOVER_QUERY_KEY)
    session[DISCOVER_SERVER_EPOCH_KEY] = current
    remove_instance_variable(:@stored_discover_query) if defined?(@stored_discover_query)
    @stored_discover_query = nil
    # A dq token in the URL may be a fresh feature-link payload; do not block loading it.
    @discover_query_fresh = params[:dq].blank?
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
    return false unless phrases.is_a?(Hash)
    return true if phrases.length > 4

    # Keep complex queries (any exclude phrase) behind a token so shared URLs
    # stay clean. Generic — no feature identity involved.
    phrases.values.any? do |row|
      value = row["exclude"] || row[:exclude]
      value.to_s == "1" || value == true || value.to_s.casecmp("true").zero?
    end
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
end
