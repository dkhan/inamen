# frozen_string_literal: true

class ScripturesController < ApplicationController
  include EditionSelectable

  before_action :assign_chapter_context, only: :chapter
  after_action :remember_chapter, only: :chapter

  def show
    ref = session_scripture_ref
    redirect_to scripture_chapter_path(
      book: ref[:book],
      chapter: ref[:chapter],
      edition: current_edition_id
    )
  end

  def chapter
    unless Inamen::BookCategories.book_set.include?(@book)
      redirect_to scripture_path_with_state, alert: "Unknown book: #{@book}"
      return
    end

    if @chapter <= 0
      redirect_to scripture_path_with_state, alert: "Invalid chapter."
      return
    end

    @verses = @edition.chapter_verses(book: @book, chapter: @chapter)
    if @verses.empty?
      redirect_to scripture_path_with_state, alert: "Chapter not found."
      return
    end

    @superscription_text = @edition.chapter_superscription(book: @book, chapter: @chapter)
    @colophon_text = @edition.chapter_colophon(book: @book, chapter: @chapter)
    @highlight_extra_bucket = highlight_extra_bucket?
    @highlight_scroll_target = highlight_scroll_target
    @scripture_books = @edition.books
    @scripture_chapters = @edition.chapter_numbers(@book)

    @prev_chapter = previous_chapter_ref
    @next_chapter = next_chapter_ref
    @title = "#{@book} #{@chapter}"
  end

  def edition_selection_redirect_path
    scripture_path_with_state
  end

  private

  def assign_chapter_context
    @book = params[:book].to_s
    @chapter = params[:chapter].to_i
    @highlight_verse = params[:highlight].to_i
    @highlight_indices = parse_highlight_indices(params[:hi])
    @bucket = params[:bucket].presence || Inamen::CorpusStore::BUCKET_VERSE_TEXT
  end

  def remember_chapter
    return if performed?

    store_scripture_ref!(book: @book, chapter: @chapter)
  end

  def parse_highlight_indices(raw)
    return [] if raw.blank?

    raw.to_s.split(",").filter_map do |part|
      value = part.strip.to_i
      value.positive? ? value : nil
    end
  end

  def highlight_extra_bucket?
    @highlight_indices.any? &&
      @bucket != Inamen::CorpusStore::BUCKET_VERSE_TEXT
  end

  def highlight_scroll_target
    return "colophon" if @highlight_extra_bucket && @bucket == Inamen::CorpusStore::BUCKET_COLOPHON
    return "superscription" if @highlight_extra_bucket && @bucket == Inamen::CorpusStore::BUCKET_PSALM_HEADING
    return "v#{@highlight_verse}" if @highlight_verse.positive? && @highlight_indices.any?

    nil
  end

  def previous_chapter_ref
    chapters = @edition.chapter_numbers(@book)
    index = chapters.index(@chapter)
    return { book: @book, chapter: chapters[index - 1] } if index&.positive?

    book_index = @edition.books.index(@book)
    return nil unless book_index&.positive?

    previous_book = @edition.books[book_index - 1]
    { book: previous_book, chapter: @edition.chapter_numbers(previous_book).last }
  end

  def next_chapter_ref
    chapters = @edition.chapter_numbers(@book)
    index = chapters.index(@chapter)
    return { book: @book, chapter: chapters[index + 1] } if index && index < chapters.length - 1

    book_index = @edition.books.index(@book)
    return nil unless book_index && book_index < @edition.books.length - 1

    next_book = @edition.books[book_index + 1]
    { book: next_book, chapter: @edition.chapter_numbers(next_book).first }
  end
end
