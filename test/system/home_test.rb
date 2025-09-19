require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "visiting the home page" do
    visit root_url
    assert_selector "h1", text: "Home#index"
  end

  test "authenticated user redirects to activities" do
    user = users(:one)
    sign_in user
    visit root_url
    assert_text "My Activities"
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
  end
end