require "test_helper"

class PlaylistTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @playlist = Playlist.new(
      user: @user,
      name: "Test Playlist",
      description: "Test description"
    )
    @activity = activities(:one)
  end

  test "should be valid" do
    assert @playlist.valid?
  end

  test "should require user" do
    @playlist.user = nil
    assert_not @playlist.valid?
    assert_includes @playlist.errors[:user], "must exist"
  end

  test "should require name" do
    @playlist.name = ""
    assert_not @playlist.valid?
    assert_includes @playlist.errors[:name], "can't be blank"
  end

  test "should generate slug from name" do
    @playlist.save!
    assert_equal "test-playlist", @playlist.slug
  end

  test "should generate unique slug when name conflicts" do
    @playlist.save!
    playlist2 = Playlist.create!(
      user: @user,
      name: "Test Playlist"
    )
    assert_equal "test-playlist-1", playlist2.slug
  end

  test "should require unique slug" do
    @playlist.save!
    playlist2 = Playlist.new(
      user: @user,
      name: "Different Playlist",
      slug: "test-playlist"
    )
    assert_not playlist2.valid?
    assert_includes playlist2.errors[:slug], "has already been taken"
  end

  test "should use to_param as slug" do
    @playlist.save!
    assert_equal @playlist.slug, @playlist.to_param
  end

  test "archived? should return false when not archived" do
    assert_not @playlist.archived?
  end

  test "archived? should return true when archived" do
    @playlist.archived_at = Time.current
    assert @playlist.archived?
  end

  test "archive! should set archived_at" do
    @playlist.save!
    assert_nil @playlist.archived_at
    @playlist.archive!
    assert_not_nil @playlist.archived_at
  end

  test "should have many playlist_activities" do
    @playlist.save!
    playlist_activity = @playlist.playlist_activities.create!(
      activity: @activity,
      position: 1
    )
    assert_includes @playlist.playlist_activities, playlist_activity
  end

  test "should have many activities through playlist_activities" do
    @playlist.save!
    @playlist.playlist_activities.create!(
      activity: @activity,
      position: 1
    )
    assert_includes @playlist.activities, @activity
  end

  test "active scope should exclude archived playlists" do
    active_playlist = playlists(:one)
    archived_playlist = Playlist.create!(
      user: @user,
      name: "Archived Playlist",
      archived_at: Time.current
    )

    active_playlists = Playlist.active
    assert_includes active_playlists, active_playlist
    assert_not_includes active_playlists, archived_playlist
  end

  test "ordered_activities should return activities in position order" do
    @playlist.save!
    activity2 = Activity.create!(
      user: @user,
      name: "Second Activity",
      schedule_type: "flexible"
    )

    # Add activities in reverse order
    @playlist.playlist_activities.create!(activity: activity2, position: 1)
    @playlist.playlist_activities.create!(activity: @activity, position: 2)

    ordered = @playlist.ordered_activities
    assert_equal activity2, ordered.first
    assert_equal @activity, ordered.second
  end

  test "ordered_activities should exclude archived playlist_activities" do
    @playlist.save!
    playlist_activity = @playlist.playlist_activities.create!(
      activity: @activity,
      position: 1,
      archived_at: Time.current
    )

    assert_not_includes @playlist.ordered_activities, @activity
  end

  test "add_activity should create playlist_activity with position" do
    @playlist.save!

    assert_difference("@playlist.playlist_activities.count") do
      @playlist.add_activity(@activity)
    end

    playlist_activity = @playlist.playlist_activities.last
    assert_equal @activity, playlist_activity.activity
    assert_equal 1, playlist_activity.position
  end

  test "add_activity should use custom position when provided" do
    @playlist.save!
    @playlist.add_activity(@activity, position: 5)

    playlist_activity = @playlist.playlist_activities.last
    assert_equal 5, playlist_activity.position
  end

  test "add_activity should increment position when adding multiple activities" do
    @playlist.save!
    activity2 = Activity.create!(
      user: @user,
      name: "Second Activity",
      schedule_type: "flexible"
    )

    @playlist.add_activity(@activity)
    @playlist.add_activity(activity2)

    positions = @playlist.playlist_activities.pluck(:position).sort
    assert_equal [ 1, 2 ], positions
  end

  test "remove_activity should archive playlist_activity" do
    @playlist.save!
    playlist_activity = @playlist.playlist_activities.create!(
      activity: @activity,
      position: 1
    )

    assert_nil playlist_activity.archived_at
    @playlist.remove_activity(@activity)
    playlist_activity.reload
    assert_not_nil playlist_activity.archived_at
  end

  test "remove_activity should handle activity not in playlist" do
    @playlist.save!
    other_activity = Activity.create!(
      user: @user,
      name: "Other Activity",
      schedule_type: "flexible"
    )

    # Should not raise error
    assert_nothing_raised do
      @playlist.remove_activity(other_activity)
    end
  end
end
