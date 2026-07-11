# frozen_string_literal: true

class FeaturesController < ApplicationController
  include EditionSelectable

  before_action :load_saved_feature, only: %i[edit update destroy]
  before_action :ensure_saved_feature!, only: %i[edit update destroy]

  def index
    @catalog = Inamen::Features.catalog
    @status = page_status
    @saved_rows = SavedFeatureCatalog.rows_for_edition(@edition)

    return unless @status == :ready

    @rows = FeatureCatalog.read_cached(@edition)
    @match_count = @rows.count(&:match)
  end

  def new
    @discover_query = stored_discover_query
    unless savable_discover_query?(@discover_query)
      redirect_to discoveries_path(edition: current_edition_id), alert: "Run a word count scan before saving a feature."
      return
    end

    @actual_count = params[:actual_count].to_i
    @actual_count = @discover_query["saved_actual_count"].to_i if @actual_count <= 0 && @discover_query["saved_actual_count"].present?

    selection = Inamen::SearchSelection.from_params(resolved_search_selection(@discover_query))
    phrases = @discover_query["search_phrases"] || {}

    @saved_feature = SavedFeature.new(
      edition_id: current_edition_id,
      scope_label: selection.label,
      unit: "occurrences",
      expected_count: @actual_count.positive? ? @actual_count : 0,
      saved_actual_count: @actual_count.positive? ? @actual_count : 0,
      mode: @discover_query["mode"].presence || "word_count",
      search_selection: resolved_search_selection(@discover_query),
      search_phrases: phrases,
      from_feature: @discover_query["from_feature"],
      details: SavedFeature.build_details_from_phrases(phrases)
    )
  end

  def create
    @saved_feature = SavedFeature.new(saved_feature_params)
    @saved_feature.details = SavedFeature.build_details_from_phrases(@saved_feature.search_phrases)
    if @saved_feature.scope_label.blank?
      @saved_feature.scope_label = SavedFeature.scope_label_for(@saved_feature.search_selection)
    end

    if @saved_feature.save
      redirect_to features_path(edition: @saved_feature.edition_id), notice: "Feature \"#{@saved_feature.name}\" saved."
      return
    end

    @discover_query = stored_discover_query
    @actual_count = @saved_feature.saved_actual_count
    render :new, status: :unprocessable_entity
  end

  def edit
    @row = SavedFeatureCatalog.row_for(@saved_feature, @edition)
  end

  def update
    if @saved_feature.update(saved_feature_update_params)
      redirect_to features_path(edition: @saved_feature.edition_id), notice: "Feature \"#{@saved_feature.name}\" updated."
      return
    end

    @row = SavedFeatureCatalog.row_for(@saved_feature, @edition)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    edition_id = @saved_feature.edition_id
    name = @saved_feature.name
    @saved_feature.destroy!
    redirect_to features_path(edition: edition_id), notice: "Feature \"#{name}\" deleted."
  end

  def verify
    edition_id = current_edition_id
    force = params[:refresh] == "1"
    edition = @edition

    if !force && FeatureCatalog.cached?(edition)
      redirect_to features_path(edition: edition_id)
      return
    end

    FeatureCatalog.clear_cache!(edition) if force

    if edition.corpus_ready?
      FeatureCatalog.run_all(edition, force: force)
      redirect_to features_path(edition: edition_id)
      return
    end

    unless FeatureCatalog.verification_running?(edition)
      FeatureVerificationJob.perform_later(edition_id, force: false)
    end

    redirect_to features_path(edition: edition_id, waiting: 1)
  end

  def show
    if SavedFeature.url_id?(params[:id])
      @saved_feature = SavedFeature.find_by_url_id!(params[:id])
      @row = SavedFeatureCatalog.row_for(@saved_feature, @edition)
      return
    end

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

  def edition_selection_redirect_path
    features_path
  end

  def page_status
    return :ready if FeatureCatalog.cached?(@edition)
    return :computing if FeatureCatalog.verification_running?(@edition) || params[:waiting].present?

    :pending
  end

  def savable_discover_query?(query)
    return false if query.blank?

    query["mode"].to_s == "word_count" && query["search_phrases"].present?
  end

  def saved_feature_params
    raw = params.require(:saved_feature)
    attrs = raw.permit(
      :name,
      :edition_id,
      :scope_label,
      :unit,
      :expected_count,
      :saved_actual_count,
      :mode,
      :from_feature,
      :notes,
      :kjvcode_url,
      :search_selection_json,
      :search_phrases_json
    ).to_h

    attrs[:search_selection] = parse_json_param(raw[:search_selection_json]) if raw[:search_selection_json].present?
    attrs[:search_phrases] = parse_json_param(raw[:search_phrases_json]) if raw[:search_phrases_json].present?
    attrs.except("search_selection_json", "search_phrases_json", :search_selection_json, :search_phrases_json)
  end

  def saved_feature_update_params
    params.require(:saved_feature).permit(:name, :expected_count, :notes, :kjvcode_url)
  end

  def load_saved_feature
    @saved_feature = SavedFeature.find_by_url_id!(params[:id])
  end

  def ensure_saved_feature!
    return if SavedFeature.url_id?(params[:id])

    raise ActiveRecord::RecordNotFound
  end

  def resolved_search_selection(query)
    selection = query["search_selection"]
    return selection if selection.is_a?(Hash) && selection.present?

    Inamen::SearchSelection.default.to_query_hash
  end

  def parse_json_param(value)
    JSON.parse(value)
  rescue JSON::ParserError
    {}
  end
end
