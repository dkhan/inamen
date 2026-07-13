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

  def scripture_bucket_html(edition, book:, chapter:, bucket:, highlight_indices: [])
    if highlight_indices.any?
      Inamen::VerseHighlighter.highlight_verse(
        edition.db,
        book: book,
        chapter: chapter,
        verse: 0,
        bucket: bucket,
        highlight_indices: highlight_indices
      )
    else
      text = Inamen::VerseHighlighter.bucket_text(
        edition.db,
        book: book,
        chapter: chapter,
        verse: 0,
        bucket: bucket
      )
      h(text)
    end
  end
end
