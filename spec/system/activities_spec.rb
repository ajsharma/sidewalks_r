require "rails_helper"

RSpec.describe "Activities", type: :system do
  let(:user) { create(:user) }
  let(:activity) { create(:activity, user: user) }

  before do
    sign_in user
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
    visit edit_activity_url(activity)
    expect(page).to have_field "Name"
    expect(page).to have_field "Description"
  end

  it "showing an activity" do
    visit activity_url(activity)
    expect(page).to have_content activity.name
  end
end
