# frozen_string_literal: true

class DiscoveriesController < ApplicationController
  include EditionSelectable

  before_action :set_scan_params
  after_action :persist_discover_query, only: %i[index scan verses]

  def index
    @edition.warm! if @scan_params.mode == "word_count"
    @status = page_status

    return unless @status == :ready

    @rows = DiscoveryScan.read_counts_cached(@edition, @scan_params) || []
    @verse_result = DiscoveryScan.read_verses_cached(@edition, @scan_params) if @scan_params.mode == "word_count"
  end

  def dictionary
    @edition.warm!
    expires_in 7.days, public: false
    render json: { words: @edition.dictionary_words }
  end

  def verses
    unless DiscoveryScan.counts_cached?(@edition, @scan_params)
      head :no_content
      return
    end

    if DiscoveryScan.verses_cached?(@edition, @scan_params)
      @verse_result = DiscoveryScan.read_verses_cached(@edition, @scan_params)
      @edition.warm!
      render partial: "verse_results", locals: { edition: @edition, verse_result: @verse_result },
             layout: false
      return
    end

    DiscoveryScan.enqueue_verses!(@edition, @scan_params)
    render partial: "verse_loading", layout: false, status: :accepted
  end

  def scan
    edition_id = current_edition_id
    edition = @edition
    scan_params = DiscoveryScan.normalize(scan_param_hash)

    if scan_params.search_selection.empty?
      redirect_to discoveries_path(scan_query(edition_id, scan_params)), alert: "Select at least one book or text type."
      return
    end

    if scan_params.mode == "word_count" && !DiscoveryScan.enabled_search_terms?(scan_params.query_terms)
      redirect_to discoveries_path(scan_query(edition_id, scan_params)), alert: "Enter at least one search term."
      return
    end

    if scan_params.mode == "word_count" && !DiscoveryScan.valid_search_terms?(edition, scan_params.query_terms, raw_phrases: params[:search_phrases])
      redirect_to discoveries_path(scan_query(edition_id, scan_params))
      return
    end

    if params[:refresh] != "1" && DiscoveryScan.counts_cached?(edition, scan_params)
      run_or_enqueue_verses!(edition, scan_params)
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
    if @scan_params.mode == "word_count" && invalid_word_count_phrases?
      return :pending
    end

    return :ready if DiscoveryScan.counts_cached?(@edition, @scan_params)
    return :computing if DiscoveryScan.running?(@edition, @scan_params) || params[:waiting].present?

    :pending
  end

  def set_scan_params
    @scan_params = DiscoveryScan.normalize(scan_param_hash)
  end

  def persist_discover_query
    return unless @scan_params

    store_discover_query!(current_discover_query)
  end

  def current_discover_query
    query = scan_query(current_edition_id, @scan_params)
    if params[:search_phrases].present?
      query[:search_phrases] = search_phrases_param_hash(params[:search_phrases])
    elsif session.dig(:discover_query, "search_phrases").present?
      query[:search_phrases] = session[:discover_query]["search_phrases"]
    end
    query
  end

  def scan_param_hash
    {
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

  def scan_query(edition_id, scan_params)
    selection = scan_params.search_selection
    query = {
      edition: edition_id,
      mode: scan_params.mode,
      divisible_by: scan_params.divisible_by,
      min_count: scan_params.min_count,
      min_group_size: scan_params.min_group_size,
      match_by: scan_params.match_by,
      query_terms: scan_params.query_terms
    }

    if scan_params.mode == "word_count"
      if params[:search_phrases].present?
        query[:search_phrases] = search_phrases_param_hash(params[:search_phrases])
      elsif session.dig(:discover_query, "search_phrases").present?
        query[:search_phrases] = session[:discover_query]["search_phrases"]
      end
    end

    return query if selection.default?

    selection_query = {
      submitted: "1",
      colophons: selection.colophons ? "1" : "0",
      superscriptions: selection.superscriptions ? "1" : "0"
    }
    if selection.books.sort == Inamen::BookCategories.all_books.sort
      selection_query[:all_books] = "1"
    else
      selection_query[:books] = selection.books
    end
    query[:search_selection] = selection_query
    query
  end

  def search_phrases_param_hash(raw_phrases)
    if raw_phrases.is_a?(ActionController::Parameters)
      raw_phrases.permit!.to_h
    else
      raw_phrases.to_h
    end
  end

  def run_or_enqueue_verses!(edition, scan_params, force: false)
    if edition.word_stream_index
      DiscoveryScan.run_verses(edition, scan_params, force: force)
    else
      DiscoveryScan.enqueue_verses!(edition, scan_params, force: force)
    end
  end

  def invalid_word_count_phrases?
    phrases = current_search_phrases_hash
    return false unless DiscoveryScan.phrase_entries_for_validation(@scan_params.query_terms, raw_phrases: phrases).any?

    !DiscoveryScan.valid_search_terms?(@edition, @scan_params.query_terms, raw_phrases: phrases)
  end

  def current_search_phrases_hash
    if params[:search_phrases].present?
      search_phrases_param_hash(params[:search_phrases])
    elsif session.dig(:discover_query, "search_phrases").present?
      session[:discover_query]["search_phrases"]
    end
  end
end
