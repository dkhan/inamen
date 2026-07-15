# frozen_string_literal: true

module EditionSelectable
  extend ActiveSupport::Concern

  included do
    helper_method :current_edition_id
    before_action :set_edition
  end

  private

  def current_edition_id
    @edition&.edition_id || EditionContext.default_id
  end

  def set_edition
    edition_id = params[:edition].presence || session[:edition_id].presence || EditionContext.default_id
    unless edition_id
      redirect_to root_path, alert: "Import an edition before using this page."
      return
    end

    unless EditionContext.all_ids.include?(edition_id)
      session.delete(:edition_id)
      fallback_id = EditionContext.default_id
      redirect_to unknown_edition_redirect_path(fallback_id),
                  alert: "Unknown edition: #{edition_id}"
      return
    end

    session[:edition_id] = edition_id
    @edition = EditionContext.new(edition_id)
  end

  def edition_selection_redirect_path
    raise NotImplementedError
  end

  def unknown_edition_redirect_path(fallback_id)
    return root_path unless fallback_id

    url_for(request.query_parameters.merge(edition: fallback_id, only_path: true))
  end
end
