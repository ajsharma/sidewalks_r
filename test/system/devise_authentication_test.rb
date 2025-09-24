require "application_system_test_case"

class DeviseAuthenticationTest < ApplicationSystemTestCase
  test "visiting the sign in page" do
    visit new_user_session_path
    assert_selector "h2", text: "Sign in to your account"
  end

  test "signing in with valid credentials" do
    user = users(:one)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_text "Signed in successfully"
  end

  test "visiting the sign up page" do
    visit new_user_registration_path
    assert_selector "h2", text: "Create your account"
  end

  test "visiting the forgot password page" do
    visit new_user_password_path
    assert_selector "h2", text: "Forgot your password?"
  end

  test "sign up form has required fields" do
    visit new_user_registration_path
    assert_field "Email"
    assert_field "Password"
  end

  test "edit registration page loads" do
    user = users(:one)
    sign_in user
    visit edit_user_registration_path
    assert_text "Edit Profile"
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
    # Wait for successful authentication by checking for the user's name in the navigation
    assert_text user.name
    # Ensure we're redirected away from the sign-in page
    assert_current_path root_path
  end
end
