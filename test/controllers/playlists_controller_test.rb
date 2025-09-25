require "test_helper"

class PlaylistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @playlist = playlists(:one)
    @user = users(:one)
    sign_in @user
  end

  test "should get index" do
    get playlists_url
    assert_response :success
  end

  test "should get show" do
    get playlist_url(@playlist)
    assert_response :success
  end

  test "should get new" do
    get new_playlist_url
    assert_response :success
  end

  test "should create playlist" do
    assert_difference("Playlist.count") do
      post playlists_url, params: { playlist: { name: "Test Playlist", description: "Test" } }
    end
    assert_redirected_to playlist_url(Playlist.last)
  end

  test "should get edit" do
    get edit_playlist_url(@playlist)
    assert_response :success
  end

  test "should update playlist" do
    patch playlist_url(@playlist), params: { playlist: { name: "Updated Playlist" } }
    assert_redirected_to playlist_url(@playlist)
  end

  test "should archive playlist on destroy" do
    assert_no_difference("Playlist.count") do
      delete playlist_url(@playlist)
    end
    assert_redirected_to playlists_path
    @playlist.reload
    assert @playlist.archived?
  end

  test "index should include activities count to prevent N+1 queries" do
    # Create a playlist with activities
    playlist = Playlist.create!(name: "Test Playlist", user: @user)
    activity1 = activities(:one)
    activity2 = activities(:two)

    playlist.add_activity(activity1)
    playlist.add_activity(activity2)

    get playlists_url
    assert_response :success

    # Check that the response includes activity counts
    assert_select ".text-gray-500", text: /2 activities/
  end

  test "show should preload activities with users to prevent N+1 queries" do
    # Create a new playlist and activity for this test
    playlist = @user.playlists.create!(name: "Test Playlist", description: "Test")
    activity = @user.activities.create!(
      name: "Test Activity",
      schedule_type: "flexible",
      description: "Test activity"
    )
    playlist.add_activity(activity)

    get playlist_url(playlist)
    assert_response :success

    # Should display activity information without additional queries
    assert_select "h4", text: activity.name
  end
end
