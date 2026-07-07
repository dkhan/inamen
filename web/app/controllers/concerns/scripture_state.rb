# frozen_string_literal: true

module ScriptureState
  extend ActiveSupport::Concern

  DEFAULT_BOOK = "Genesis"
  DEFAULT_CHAPTER = 1

  included do
    helper_method :scripture_path_with_state
  end

  def store_scripture_ref!(book:, chapter:)
    session[:scripture_ref] = {
      "book" => book.to_s,
      "chapter" => Integer(chapter)
    }
  end

  def session_scripture_ref
    stored = session[:scripture_ref]
    if stored.present?
      {
        book: stored["book"].to_s,
        chapter: stored["chapter"].to_i
      }
    else
      { book: DEFAULT_BOOK, chapter: DEFAULT_CHAPTER }
    end
  end

  def scripture_path_with_state(extra = {})
    ref = session_scripture_ref
    scripture_chapter_path(
      {
        book: ref[:book],
        chapter: ref[:chapter],
        edition: current_edition_id
      }.merge(extra)
    )
  end
end
