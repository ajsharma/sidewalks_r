require "test_helper"

class ErbCoverageTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "devise pages render correctly" do
    # Sign in page
    get "/users/sign_in"
    assert_response :success
    assert_select "h2", text: "Sign in to your account"

    # Sign up page
    get "/users/sign_up"
    assert_response :success
    assert_select "h2", text: "Create your account"

    # Forgot password page
    get "/users/password/new"
    assert_response :success
    assert_select "h2", text: "Forgot your password?"
  end

  test "home page renders" do
    get "/"
    assert_response :success
    assert_select "h1", text: "Home#index"
  end

  test "activities pages render when authenticated" do
    sign_in @user

    # Activities index
    get "/activities"
    assert_response :success
    assert_select "h1", text: "My Activities"

    # New activity page
    get "/activities/new"
    assert_response :success
    assert_select "input[name='activity[name]']"

    # Show activity page
    activity = activities(:one)
    get "/activities/#{activity.id}"
    assert_response :success

    # Edit activity page
    get "/activities/#{activity.id}/edit"
    assert_response :success
    assert_select "input[name='activity[name]']"
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

    # Show playlist page
    playlist = playlists(:one)
    get "/playlists/#{playlist.id}"
    assert_response :success

    # Edit playlist page
    get "/playlists/#{playlist.id}/edit"
    assert_response :success
    assert_select "input[name='playlist[name]']"
  end

  test "schedule page renders when authenticated" do
    sign_in @user

    get "/schedule"
    assert_response :success
  end

  test "edit registration page renders when authenticated" do
    sign_in @user

    get "/users/edit"
    assert_response :success
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