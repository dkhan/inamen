# frozen_string_literal: true

class DiscoveriesController < ApplicationController
  include EditionSelectable

  before_action :reset_discover_query_if_server_restarted!
  before_action :set_scan_params
  before_action :persist_discover_query_before_scan, only: :scan
  after_action :persist_discover_query, only: %i[index verses]

  def index
    maybe_run_feature_auto_scan!
    @status = page_status

    return unless @status == :ready

    if @scan_params.mode == "file_stats"
      @file_stats = DiscoveryScan.read_cached(@edition, @scan_params)
    else
      @rows = DiscoveryScan.read_counts_cached(@edition, @scan_params) || []
    end
  end

  def dictionary
    @edition.word_stream_index
    expires_in 7.days, public: false
    render json: { words: @edition.dictionary_words }
  end

  def verses
    unless DiscoveryScan.counts_cached?(@edition, @scan_params)
      head :no_content
      return
    end

    if @edition.corpus_ready? && !DiscoveryScan.verses_cached?(@edition, @scan_params)
      DiscoveryScan.run_verses(@edition, @scan_params, force: false, validate: false)
    end

    if DiscoveryScan.verses_cached?(@edition, @scan_params)
      offset = [params[:offset].to_i, 0].max
      limit = Inamen::VerseMatchQuery::DISPLAY_LIMIT
      if params[:offset].present?
        render_cached_verses_partial(
          partial: "verse_result_rows",
          cache_partial: :rows,
          offset: offset,
          limit: limit
        )
      else
        render_cached_verses_partial(
          partial: "verse_results",
          cache_partial: :full,
          offset: 0,
          limit: limit
        )
      end
      return
    end

    DiscoveryScan.enqueue_verses!(@edition, @scan_params)
    render partial: "verse_loading", layout: false, status: :accepted
  end

  def scan
    edition_id = current_edition_id
    edition = @edition
    scan_params = build_scan_params

    if scan_params.mode == "file_stats"
      DiscoveryScan.clear_cache!(edition, scan_params) if params[:refresh] == "1"
      DiscoveryScan.run_file_stats(edition, scan_params, force: params[:refresh] == "1")
      redirect_to discoveries_path(scan_query(edition_id, scan_params))
      return
    end

    if scan_params.search_selection.empty?
      redirect_to discoveries_path(scan_query(edition_id, scan_params)), alert: "Select at least one book or text type."
      return
    end

    if scan_params.mode == "word_count" && !DiscoveryScan.enabled_search_terms?(scan_params.query_terms)
      redirect_to discoveries_path(scan_query(edition_id, scan_params)), alert: "Enter at least one search term."
      return
    end

    if params[:refresh] != "1" && DiscoveryScan.counts_cached?(edition, scan_params)
      run_or_enqueue_verses!(edition, scan_params, validate: false)
      redirect_to discoveries_path(scan_query(edition_id, scan_params))
      return
    end

    if scan_params.mode == "word_count" && !DiscoveryScan.valid_search_terms?(edition, scan_params.query_terms)
      redirect_to discoveries_path(scan_query(edition_id, scan_params))
      return
    end

    if params[:refresh] == "1"
      DiscoveryScan.clear_counts_cache!(edition, scan_params)
      DiscoveryScan.clear_verses_cache!(edition, scan_params)
    end

    if scan_params.mode == "word_count" && edition.corpus_ready?
      DiscoveryScan.run_counts(edition, scan_params, force: params[:refresh] == "1")
      run_or_enqueue_verses!(edition, scan_params, force: params[:refresh] == "1")
      redirect_to discoveries_path(scan_query(edition_id, scan_params))
      return
    end

    unless DiscoveryScan.running?(edition, scan_params)
      DiscoveryScanJob.perform_later(edition_id, DiscoveryScan.job_payload(scan_params), force: false)
    end

    redirect_to discoveries_path(scan_query(edition_id, scan_params).merge(waiting: 1))
  end

  private

  def edition_selection_redirect_path
    discoveries_path(discover_query_params)
  end

  def page_status
    return :ready if @scan_params.mode == "file_stats"

    return :ready if DiscoveryScan.counts_cached?(@edition, @scan_params)

    if @scan_params.mode == "word_count" && invalid_word_count_phrases?
      return :pending
    end

    return :computing if DiscoveryScan.running?(@edition, @scan_params) || params[:waiting].present?

    :pending
  end

  def set_scan_params
    @scan_params = build_scan_params
  end

  def build_scan_params
    hash = scan_param_hash
    hash[:search_phrases] =
      if request.post? && action_name == "scan" && params[:search_phrases].present?
        search_phrases_param_hash(params[:search_phrases])
      else
        discover_search_phrases_hash(hash[:search_phrases])
      end
    if hash[:search_phrases].blank? && hash[:query_terms].blank? && stored_discover_query&.dig("query_terms").present?
      hash[:query_terms] = stored_discover_query["query_terms"]
    end
    DiscoveryScan.normalize(hash)
  end

  def maybe_run_feature_auto_scan!
    return unless params[:auto_scan] == "1"
    return unless @scan_params.mode == "word_count"
    return unless @edition.corpus_ready?

    unless DiscoveryScan.counts_cached?(@edition, @scan_params)
      DiscoveryScan.run_counts(@edition, @scan_params, force: false, validate: false)
    end
    run_or_enqueue_verses!(@edition, @scan_params, validate: false)
  end

  def persist_discover_query
    return unless @scan_params

    store_discover_query!(discover_query_snapshot)
  end

  def persist_discover_query_before_scan
    return unless @scan_params

    store_discover_query!(discover_query_snapshot)
  end

  def discover_query_snapshot
    query = scan_query(current_edition_id, @scan_params, for_storage: true)
    raw = params[:search_phrases].present? ? search_phrases_param_hash(params[:search_phrases]) : nil
    if request.post? && action_name == "scan" && raw.present?
      query[:search_phrases] = raw
    else
      phrases = discover_search_phrases_hash(params[:search_phrases])
      query[:search_phrases] = phrases if phrases.present?
    end
    query.except(:auto_scan, :dq, :query_terms)
  end

  def current_discover_query
    discover_query_snapshot
  end

  def scan_param_hash
    stored = stored_discover_query || feature_discover_query
    hash = {
      mode: params[:mode],
      divisible_by: params[:divisible_by],
      search_selection: search_selection_param_hash,
      scope: params[:scope],
      bucket: params[:bucket],
      min_count: params[:min_count],
      min_group_size: params[:min_group_size],
      match_by: params[:match_by],
      query_terms: params[:query_terms],
      search_phrases: params[:search_phrases]
    }

    if hash[:search_selection].blank? && stored&.dig("search_selection").present?
      hash[:search_selection] = stored["search_selection"]
    end

    hash
  end

  def search_selection_param_hash
    return params[:search_selection].to_unsafe_h if params[:search_selection].present?
    return nil unless params[:submitted].present? || params[:books].present?

    {
      submitted: params[:submitted],
      colophons: params[:colophons],
      superscriptions: params[:superscriptions],
      books: params[:books],
      all_books: params[:all_books]
    }.compact
  end

  def scan_query(edition_id, scan_params, for_storage: false)
    selection = scan_params.search_selection
    query = {
      edition: edition_id,
      mode: scan_params.mode,
      divisible_by: scan_params.divisible_by,
      min_count: scan_params.min_count,
      min_group_size: scan_params.min_group_size,
      match_by: scan_params.match_by
    }
    unless for_storage || use_discover_query_token_in_urls?
      query[:query_terms] = scan_params.query_terms
    end

    if for_storage || !use_discover_query_token_in_urls?
      if scan_params.mode == "word_count"
        phrases = nil
        if params[:search_phrases].present?
          phrases = search_phrases_param_hash(params[:search_phrases])
        elsif stored_discover_query&.dig("search_phrases").present?
          phrases = stored_discover_query["search_phrases"]
        end
        query[:search_phrases] = phrases if phrases.present?
      end
    end

    return query if selection.default? && !for_storage

    query[:search_selection] = selection.to_query_hash
    query[:dq] = session[DISCOVER_QUERY_ID_KEY] if !for_storage && use_discover_query_token_in_urls?
    query
  end

  def search_phrases_param_hash(raw_phrases)
    if raw_phrases.is_a?(ActionController::Parameters)
      raw_phrases.permit!.to_h
    else
      raw_phrases.to_h
    end
  end

  def run_or_enqueue_verses!(edition, scan_params, force: false, validate: true)
    if edition.corpus_ready?
      DiscoveryScan.run_verses(edition, scan_params, force: force, validate: validate)
    else
      DiscoveryScan.enqueue_verses!(edition, scan_params, force: force, validate: validate)
    end
  end

  def render_cached_verses_partial(partial:, cache_partial:, offset:, limit:)
    cache_key = DiscoveryScan.verses_display_cache_key_for(
      @edition,
      @scan_params,
      offset: offset,
      limit: limit,
      partial: cache_partial
    )

    html = Rails.cache.fetch(cache_key, expires_in: 7.days) do
      rows = DiscoveryScan.read_counts_cached(@edition, @scan_params) || []
      verse_result = DiscoveryScan.read_verses_cached(@edition, @scan_params)
      DiscoveryScan.prepare_verses_for_display!(@edition, verse_result, rows: rows, offset: offset, limit: limit)
      render_to_string(
        partial: partial,
        locals: {
          edition: @edition,
          verse_result: verse_result,
          offset: offset,
          limit: limit
        },
        layout: false
      )
    end

    render html: html.html_safe, layout: false
  end

  def invalid_word_count_phrases?
    phrases = current_search_phrases_hash
    return false unless DiscoveryScan.phrase_entries_for_validation(@scan_params.query_terms, raw_phrases: phrases).any?

    !DiscoveryScan.valid_search_terms?(@edition, @scan_params.query_terms, raw_phrases: phrases)
  end

  def current_search_phrases_hash
    discover_search_phrases_hash(params[:search_phrases])
  end

  def discover_search_phrases_hash(raw_phrases = nil)
    raw = search_phrases_param_hash(raw_phrases) if raw_phrases.present?
    raw = stored_discover_query&.dig("search_phrases") if raw.blank?
    raw = feature_discover_query&.dig("search_phrases") if raw.blank?
    raw || {}
  end

  def feature_discover_query
    return @feature_discover_query if defined?(@feature_discover_query)

    feature_id = params[:feature].presence || stored_discover_query&.dig("from_feature").presence
    @feature_discover_query =
      if SavedFeature.url_id?(feature_id)
        feature = SavedFeature.find_by_url_id!(feature_id)
        {
          "mode" => feature.mode,
          "search_selection" => feature.search_selection,
          "search_phrases" => feature.search_phrases,
          "from_feature" => feature.url_id
        }
      end
  rescue ActiveRecord::RecordNotFound
    @feature_discover_query = nil
  end
end
