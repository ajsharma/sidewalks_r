require "rails_helper"

RSpec.describe "Health", type: :system do
  it "visiting the health page renders JSON" do
    visit health_url
    expect(page).to have_content "status"
    expect(page).to have_content "healthy"
  end
end
