# frozen_string_literal: true

require "test_helper"

class ScripturesControllerTest < ActionDispatch::IntegrationTest
  FakeEdition = Struct.new(:edition_id, keyword_init: true) do
    def warm!
      raise "scripture pages must not warm scan indexes"
    end

    def chapter_verses(book:, chapter:)
      return {} unless book == "Genesis" && chapter.to_i == 1

      { 1 => "In the beginning God created the heaven and the earth." }
    end

    def chapter_superscription(book:, chapter:)
      nil
    end

    def chapter_colophon(book:, chapter:)
      nil
    end

    def books
      %w[Genesis Exodus]
    end

    def chapter_numbers(book)
      { "Genesis" => [1, 2], "Exodus" => [1] }.fetch(book)
    end
  end

  test "chapter page renders from lightweight edition context with book and chapter picker" do
    fake = FakeEdition.new(edition_id: "test_edition")

    EditionContext.stub(:all_ids, ["test_edition"]) do
      EditionContext.stub(:default_id, "test_edition") do
        EditionContext.stub(:new, fake) do
          get scripture_chapter_path(book: "Genesis", chapter: 1, edition: "test_edition")
        end
      end
    end

    assert_response :success
    assert_select "h1", "Genesis 1"
    assert_select "#scripture-book-select option[selected][value=?]", "Genesis"
    assert_select "#scripture-chapter-select option[selected][value=?]", "1"
    assert_select "#scripture-book-select[data-chapters*=?]", "Genesis"
    assert_select ".scripture-verse", /In the beginning/
  end
end
