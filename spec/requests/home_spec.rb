require "rails_helper"

RSpec.describe "Home", type: :request do
  it "gets index" do
    get home_index_url
    expect(response).to have_http_status(:success)
  end
end
