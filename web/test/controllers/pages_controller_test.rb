# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home page renders imported editions" do
    get root_path

    assert_response :success
    assert_select "h1", "Inamen"
    assert_select "h2", "Editions"
  end
end
