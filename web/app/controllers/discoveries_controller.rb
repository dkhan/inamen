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

    if params[:refresh] != "1" && DiscoveryScan.cached?(edition, scan_params)
      redirect_to discoveries_path(scan_query(edition_id, scan_params))
      return
    end

    DiscoveryScan.clear_cache!(edition, scan_params) if params[:refresh] == "1"

    unless DiscoveryScan.running?(edition, scan_params)
      DiscoveryScanJob.perform_later(edition_id, scan_params.to_h, force: false)
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
      scope: params[:scope],
      bucket: params[:bucket],
      min_count: params[:min_count],
      min_group_size: params[:min_group_size],
      match_by: params[:match_by]
    }
  end

  def scan_query(edition_id, scan_params)
    {
      edition: edition_id,
      mode: scan_params.mode,
      divisible_by: scan_params.divisible_by,
      scope: scan_params.scope,
      bucket: scan_params.bucket,
      min_count: scan_params.min_count,
      min_group_size: scan_params.min_group_size,
      match_by: scan_params.match_by
    }
  end
end
