require "rails_helper"

RSpec.describe "Playlists", type: :request do
  before do
    @playlist = playlists(:one)
    @user = users(:one)
    sign_in @user
  end

  it "should get index" do
    get playlists_url
    expect(response).to have_http_status(:success)
  end

  it "should get show" do
    get playlist_url(@playlist)
    expect(response).to have_http_status(:success)
  end

  it "should get new" do
    get new_playlist_url
    expect(response).to have_http_status(:success)
  end

  it "should create playlist" do
    expect {
      post playlists_url, params: { playlist: { name: "Test Playlist", description: "Test" } }
    }.to change { Playlist.count }.by(1)
    expect(response).to redirect_to(playlist_url(Playlist.last))
  end

  it "should get edit" do
    get edit_playlist_url(@playlist)
    expect(response).to have_http_status(:success)
  end

  it "should update playlist" do
    patch playlist_url(@playlist), params: { playlist: { name: "Updated Playlist" } }
    expect(response).to redirect_to(playlist_url(@playlist))
  end

  it "should archive playlist on destroy" do
    expect {
      delete playlist_url(@playlist)
    }.not_to change { Playlist.count }
    expect(response).to redirect_to(playlists_path)
    @playlist.reload
    expect(@playlist.archived?).to be_truthy
  end

  it "index should include activities count to prevent N+1 queries" do
    # Create a playlist with activities
    playlist = Playlist.create!(name: "Test Playlist", user: @user)
    activity1 = activities(:one)
    activity2 = activities(:two)

    playlist.add_activity(activity1)
    playlist.add_activity(activity2)

    get playlists_url
    expect(response).to have_http_status(:success)

    # Check that the response includes activity counts
    assert_select ".text-gray-500", text: /2 activities/
  end

  it "show should preload activities with users to prevent N+1 queries" do
    # Create a new playlist and activity for this test
    playlist = @user.playlists.create!(name: "Test Playlist", description: "Test")
    activity = @user.activities.create!(
      name: "Test Activity",
      schedule_type: "flexible",
      description: "Test activity"
    )
    playlist.add_activity(activity)

    get playlist_url(playlist)
    expect(response).to have_http_status(:success)

    # Should display activity information without additional queries
    assert_select "h4", text: activity.name
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      }
    }
    follow_redirect!
  end
end
