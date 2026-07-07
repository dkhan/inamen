# frozen_string_literal: true

class ScripturesController < ApplicationController
  include EditionSelectable

  before_action :warm_edition
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

    @prev_chapter = Inamen::CanonNavigation.prev_chapter(@book, @chapter)
    @next_chapter = Inamen::CanonNavigation.next_chapter(@book, @chapter)
    @title = "#{@book} #{@chapter}"
  end

  def edition_selection_redirect_path
    scripture_path_with_state
  end

  private

  def warm_edition
    @edition.warm! if @edition
  end

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
end
