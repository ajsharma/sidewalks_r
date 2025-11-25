require "rails_helper"

RSpec.describe "DeviseAuthentication", type: :system do
  it "visiting the sign in page" do
    visit new_user_session_path
    expect(page).to have_selector "h2", text: "Sign in to your account"
  end

  it "signing in with valid credentials" do
    user = users(:one)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"

    expect(page).to have_content "Signed in successfully"
  end

  it "visiting the sign up page" do
    visit new_user_registration_path
    expect(page).to have_selector "h2", text: "Create your account"
  end

  it "visiting the forgot password page" do
    visit new_user_password_path
    expect(page).to have_selector "h2", text: "Forgot your password?"
  end

  it "sign up form has required fields" do
    visit new_user_registration_path
    expect(page).to have_field "Email"
    expect(page).to have_field "Password"
  end

  it "edit registration page loads" do
    user = users(:one)
    sign_in user
    visit edit_user_registration_path
    expect(page).to have_content "Edit Profile"
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
