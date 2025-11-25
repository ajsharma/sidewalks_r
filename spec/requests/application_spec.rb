require "rails_helper"

RSpec.describe "Application", type: :request do
  it "should allow modern browsers" do
    get root_path
    expect(response).to have_http_status(:success)
  end

  it "should inherit from ActionController::Base" do
    expect(ApplicationController < ActionController::Base).to be_truthy
  end
end
