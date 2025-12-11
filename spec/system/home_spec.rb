require "rails_helper"

RSpec.describe "Home", type: :system do
  it "visiting the home page" do
    visit root_url
    expect(page).to have_selector "h1", text: "Home#index"
  end

  it "authenticated user can navigate to activities" do
    user = create(:user)
    sign_in user
    visit root_url
    click_link "Activities"
    # Wait for page to load by checking for the Activities page heading
    expect(page).to have_selector "h1", text: "My Activities"
  end
end
