require "rails_helper"

RSpec.describe "ActivityScheduling", type: :system do
  before do
    @user = users(:one)
    sign_in @user
  end

  it "visiting the schedule page" do
    visit schedule_url
    expect(page).to have_content "Schedule"
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
