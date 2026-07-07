# frozen_string_literal: true

module ScripturesHelper
  def scripture_chapter_link(ref, edition_id:, **extra)
    scripture_chapter_path(
      {
        book: ref[:book],
        chapter: ref[:chapter],
        edition: edition_id
      }.merge(extra)
    )
  end

  def scripture_chapter_label(book, chapter)
    "#{book} #{chapter}"
  end
end
