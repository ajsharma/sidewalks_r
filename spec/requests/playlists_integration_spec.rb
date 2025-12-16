require "rails_helper"

RSpec.describe "PlaylistsIntegration", type: :request do
  before do
    @user = users(:one)
  end

  it "playlists pages render when authenticated" do
    sign_in @user

    # Playlists index
    get "/playlists"
    expect(response).to have_http_status(:success)

    # New playlist page
    get "/playlists/new"
    expect(response).to have_http_status(:success)
    expect(response.body).to include 'playlist[name]'
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
