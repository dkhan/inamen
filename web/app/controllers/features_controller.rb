# frozen_string_literal: true

class FeaturesController < ApplicationController
  before_action :set_edition

  def index
    @catalog = Inamen::Features.catalog
    @status = page_status

    if @status == :ready
      @rows = FeatureCatalog.read_cached(@edition)
      @match_count = @rows.count(&:match)
    end
  end

  def verify
    edition_id = params[:edition].presence || "kjv_normalized"
    unless EditionContext.all_ids.include?(edition_id)
      redirect_to features_path, alert: "Unknown edition: #{edition_id}"
      return
    end

    force = params[:refresh] == "1"
    edition = EditionContext.new(edition_id)

    if !force && FeatureCatalog.cached?(edition)
      redirect_to features_path(edition: edition_id)
      return
    end

    FeatureCatalog.clear_cache!(edition) if force

    unless FeatureCatalog.verification_running?(edition)
      FeatureVerificationJob.perform_later(edition_id, force: false)
    end

    redirect_to features_path(edition: edition_id, waiting: 1)
  end

  def show
    @entry = Inamen::Features.fetch(params[:id])
    @row = FeatureCatalog.find_row(@edition, params[:id])

    return if @row

    @status = if FeatureCatalog.verification_running?(@edition)
                :computing
              else
                :pending
              end
  rescue ArgumentError
    raise ActiveRecord::RecordNotFound
  end

  private

  def page_status
    return :ready if FeatureCatalog.cached?(@edition)
    return :computing if FeatureCatalog.verification_running?(@edition) || params[:waiting].present?

    :pending
  end

  def set_edition
    edition_id = params[:edition].presence || "kjv_normalized"
    unless EditionContext.all_ids.include?(edition_id)
      redirect_to features_path, alert: "Unknown edition: #{edition_id}"
      return
    end

    @edition = EditionContext.new(edition_id)
  end
end
