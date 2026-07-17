# frozen_string_literal: true

require "test_helper"

class NumbersControllerTest < ActionDispatch::IntegrationTest
  test "index renders lookup and examples" do
    get numbers_path

    assert_response :success
    assert_select "h1", "Numbers"
    assert_select "form"
    assert_select "a[href=?]", number_path(153)
  end

  test "index redirects lookup to number page" do
    get numbers_path, params: { number: "1,029" }

    assert_redirected_to number_path(1029)
  end

  test "show renders number facts" do
    get number_path(1029)

    assert_response :success
    assert_select "input[name=?][value=?]", "number", "1,029"
    assert_select "h2", "Prime Structure"
    assert_select "h2", "Seven Patterns"
    assert_select "h2", "Pi and Phi"
    assert_select "th", "First"
    assert_select "th", "7th"
    assert_select "th", "77th"
    assert_select "th", "777th"
    assert_select "a[href=?]", number_path(7)
    assert_select "a[href=?]", number_path(3)
    assert_select "a[href=?]", number_path(1029)
  end

  test "show rejects invalid numbers" do
    get number_path("abc")

    assert_redirected_to numbers_path
  end
end
