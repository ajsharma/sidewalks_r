require "test_helper"

class PlaylistsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "playlists pages render when authenticated" do
    sign_in @user

    # Playlists index
    get "/playlists"
    assert_response :success

    # New playlist page
    get "/playlists/new"
    assert_response :success
    assert_select "input[name='playlist[name]']"
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