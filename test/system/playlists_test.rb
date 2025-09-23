require "application_system_test_case"

class PlaylistsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
    @playlist = playlists(:one)
  end

  test "visiting the index" do
    visit playlists_url
    assert_text "Playlists"
  end

  test "visiting new playlist page" do
    visit new_playlist_url
    assert_field "Name"
    assert_field "Description"
  end

  test "visiting edit playlist page" do
    visit edit_playlist_url(@playlist)
    assert_field "Name"
    assert_field "Description"
  end

  test "showing a playlist" do
    visit playlist_url(@playlist)
    assert_text @playlist.name
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
    # Wait for successful authentication by checking for the user's name in the navigation
    assert_text user.name
  end
end
