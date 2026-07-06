# frozen_string_literal: true

class DiscoveriesController < ApplicationController
  before_action :set_edition
  before_action :set_scan_params

  def index
    @status = page_status

    return unless @status == :ready

    @rows = DiscoveryScan.read_cached(@edition, @scan_params)
  end

  def scan
    edition_id = params[:edition].presence || "kjv_normalized"
    unless EditionContext.all_ids.include?(edition_id)
      redirect_to discoveries_path, alert: "Unknown edition: #{edition_id}"
      return
    end

    edition = EditionContext.new(edition_id)
    scan_params = DiscoveryScan.normalize(scan_param_hash)

    if scan_params.search_selection.empty?
      redirect_to discoveries_path(scan_query(edition_id, scan_params)), alert: "Select at least one book or text type."
      return
    end

    if scan_params.mode == "word_count" && scan_params.query_terms.blank?
      redirect_to discoveries_path(scan_query(edition_id, scan_params)), alert: "Enter at least one search term."
      return
    end

    if params[:refresh] != "1" && DiscoveryScan.cached?(edition, scan_params)
      redirect_to discoveries_path(scan_query(edition_id, scan_params))
      return
    end

    DiscoveryScan.clear_cache!(edition, scan_params) if params[:refresh] == "1"

    if scan_params.mode == "word_count" && edition.corpus_ready?
      DiscoveryScan.run(edition, scan_params, force: params[:refresh] == "1")
      redirect_to discoveries_path(scan_query(edition_id, scan_params))
      return
    end

    unless DiscoveryScan.running?(edition, scan_params)
      DiscoveryScanJob.perform_later(edition_id, DiscoveryScan.job_payload(scan_params), force: false)
    end

    redirect_to discoveries_path(scan_query(edition_id, scan_params).merge(waiting: 1))
  end

  private

  def page_status
    return :ready if DiscoveryScan.cached?(@edition, @scan_params)
    return :computing if DiscoveryScan.running?(@edition, @scan_params) || params[:waiting].present?

    :pending
  end

  def set_edition
    edition_id = params[:edition].presence || "kjv_normalized"
    unless EditionContext.all_ids.include?(edition_id)
      redirect_to discoveries_path, alert: "Unknown edition: #{edition_id}"
      return
    end

    @edition = EditionContext.new(edition_id)
  end

  def set_scan_params
    @scan_params = DiscoveryScan.normalize(scan_param_hash)
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
      query_terms: params[:query_terms]
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
end
