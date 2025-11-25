require "rails_helper"

RSpec.describe "DeviseIntegration", type: :request do
  before do
    @user = users(:one)
  end

  it "devise pages render correctly" do
    # Sign in page
    get "/users/sign_in"
    expect(response).to have_http_status(:success)
    expect(response.body).to include "Sign in to your account"

    # Sign up page
    get "/users/sign_up"
    expect(response).to have_http_status(:success)
    expect(response.body).to include "Create your account"

    # Forgot password page
    get "/users/password/new"
    expect(response).to have_http_status(:success)
    expect(response.body).to include "Forgot your password?"
  end

  it "edit registration page renders when authenticated" do
    sign_in @user

    get "/users/edit"
    expect(response).to have_http_status(:success)
  end

  private

  def sign_in(user)
    post "/users/sign_in", params: {
      user: {
        email: user.email,
        password: "password"
      }
    }
    follow_redirect!
  end
end
