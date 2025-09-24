require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "visiting the home page" do
    visit root_url
    assert_selector "h1", text: "Home#index"
  end

  test "authenticated user can navigate to activities" do
    user = users(:one)
    sign_in user
    visit root_url
    click_link "Activities"
    # Wait for page to load by checking for the Activities page heading
    assert_selector "h1", text: "My Activities"
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
    # Wait for successful authentication by checking for the user's name in the navigation
    assert_text user.name
  end
end
