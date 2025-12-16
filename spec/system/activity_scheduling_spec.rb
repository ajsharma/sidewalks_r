require "rails_helper"

RSpec.describe "ActivityScheduling", type: :system do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  it "visiting the schedule page" do
    visit schedule_url
    expect(page).to have_content "Schedule"
  end
end
