require "rails_helper"

RSpec.describe "HomeIntegration", type: :request do
  it "home page renders" do
    get "/"
    expect(response).to have_http_status(:success)
    expect(response.body).to include "Home#index"
  end
end
