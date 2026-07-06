# frozen_string_literal: true

module EditionSelectable
  extend ActiveSupport::Concern

  DEFAULT_EDITION_ID = "kjv_normalized"

  included do
    helper_method :current_edition_id
    before_action :set_edition
  end

  private

  def current_edition_id
    @edition.edition_id
  end

  def set_edition
    edition_id = params[:edition].presence || session[:edition_id].presence || DEFAULT_EDITION_ID
    unless EditionContext.all_ids.include?(edition_id)
      redirect_to edition_selection_redirect_path,
                  alert: "Unknown edition: #{edition_id}"
      return
    end

    session[:edition_id] = edition_id
    @edition = EditionContext.new(edition_id)
  end

  def edition_selection_redirect_path
    raise NotImplementedError
  end
end
