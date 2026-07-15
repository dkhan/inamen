class ApplicationController < ActionController::Base
  include DiscoverState
  include ScriptureState

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_edition_id

  private

  def current_edition_id
    session[:edition_id].presence || EditionContext.default_id
  end
end
