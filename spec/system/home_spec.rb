require "rails_helper"

RSpec.describe "Home", type: :system do
  it "visiting the home page" do
    visit root_url
    expect(page).to have_selector "h1", text: "Home#index"
  end

  it "authenticated user can navigate to activities" do
    user = users(:one)
    sign_in user
    visit root_url
    click_link "Activities"
    # Wait for page to load by checking for the Activities page heading
    expect(page).to have_selector "h1", text: "My Activities"
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
    # Wait for successful authentication by checking for the user's name in the navigation
    expect(page).to have_content user.name
    # Ensure we're redirected away from the sign-in page
    expect(page).to have_current_path root_path
  end
end
