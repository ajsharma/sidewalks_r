require "application_system_test_case"

class ActivitiesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
    @activity = activities(:one)
  end

  test "visiting the index" do
    visit activities_url
    assert_selector "h1", text: "My Activities"
  end

  test "visiting new activity page" do
    visit new_activity_url
    assert_field "Name"
    assert_field "Description"
  end

  test "visiting edit activity page" do
    visit edit_activity_url(@activity)
    assert_field "Name"
    assert_field "Description"
  end

  test "showing an activity" do
    visit activity_url(@activity)
    assert_text @activity.name
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
