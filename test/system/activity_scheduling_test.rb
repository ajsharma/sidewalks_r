require "application_system_test_case"

class ActivitySchedulingTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "visiting the schedule page" do
    visit schedule_url
    assert_text "Schedule"
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
