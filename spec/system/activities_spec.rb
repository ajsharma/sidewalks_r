require "rails_helper"

RSpec.describe "Activities", type: :system do
  before do
    @user = users(:one)
    sign_in @user
    @activity = activities(:one)
  end

  it "visiting the index" do
    visit activities_url
    expect(page).to have_selector "h1", text: "My Activities"
  end

  it "visiting new activity page" do
    visit new_activity_url
    expect(page).to have_field "Name"
    expect(page).to have_field "Description"
  end

  it "visiting edit activity page" do
    visit edit_activity_url(@activity)
    expect(page).to have_field "Name"
    expect(page).to have_field "Description"
  end

  it "showing an activity" do
    visit activity_url(@activity)
    expect(page).to have_content @activity.name
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
