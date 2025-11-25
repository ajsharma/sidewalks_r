require "rails_helper"

RSpec.describe Playlist, type: :model do
  before do
    @user = users(:one)
    @playlist = Playlist.new(
      user: @user,
      name: "Test Playlist",
      description: "Test description"
    )
    @activity = activities(:one)
  end

  it "should be valid" do
    expect(@playlist).to be_valid
  end

  it "should require user" do
    @playlist.user = nil
    expect(@playlist).not_to be_valid
    expect(@playlist.errors[:user]).to include("must exist")
  end

  it "should require name" do
    @playlist.name = ""
    expect(@playlist).not_to be_valid
    expect(@playlist.errors[:name]).to include("can't be blank")
  end

  it "should generate slug from name" do
    @playlist.save!
    expect(@playlist.slug).to eq("test-playlist")
  end

  it "should generate unique slug when name conflicts" do
    @playlist.save!
    playlist2 = Playlist.create!(
      user: @user,
      name: "Test Playlist"
    )
    expect(playlist2.slug).to eq("test-playlist-1")
  end

  it "should require unique slug" do
    @playlist.save!
    playlist2 = Playlist.new(
      user: @user,
      name: "Different Playlist",
      slug: "test-playlist"
    )
    expect(playlist2).not_to be_valid
    expect(playlist2.errors[:slug]).to include("has already been taken")
  end

  it "should use to_param as slug" do
    @playlist.save!
    expect(@playlist.to_param).to eq(@playlist.slug)
  end

  it "archived? should return false when not archived" do
    expect(@playlist.archived?).to be_falsey
  end

  it "archived? should return true when archived" do
    @playlist.archived_at = Time.current
    expect(@playlist.archived?).to be_truthy
  end

  it "archive! should set archived_at" do
    @playlist.save!
    expect(@playlist.archived_at).to be_nil
    @playlist.archive!
    expect(@playlist.archived_at).not_to be_nil
  end

  it "should have many playlist_activities" do
    @playlist.save!
    playlist_activity = @playlist.playlist_activities.create!(
      activity: @activity,
      position: 1
    )
    expect(@playlist.playlist_activities).to include(playlist_activity)
  end

  it "should have many activities through playlist_activities" do
    @playlist.save!
    @playlist.playlist_activities.create!(
      activity: @activity,
      position: 1
    )
    expect(@playlist.activities).to include(@activity)
  end

  it "active scope should exclude archived playlists" do
    active_playlist = playlists(:one)
    archived_playlist = Playlist.create!(
      user: @user,
      name: "Archived Playlist",
      archived_at: Time.current
    )

    active_playlists = Playlist.active
    expect(active_playlists).to include(active_playlist)
    expect(active_playlists).not_to include(archived_playlist)
  end

  it "ordered_activities should return activities in position order" do
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
    expect(ordered.first).to eq(activity2)
    expect(ordered.second).to eq(@activity)
  end

  it "ordered_activities should exclude archived playlist_activities" do
    @playlist.save!
    playlist_activity = @playlist.playlist_activities.create!(
      activity: @activity,
      position: 1,
      archived_at: Time.current
    )

    expect(@playlist.ordered_activities).not_to include(@activity)
  end

  it "add_activity should create playlist_activity with position" do
    @playlist.save!

    expect { @playlist.add_activity(@activity) }.to change { @playlist.playlist_activities.count }.by(1)

    playlist_activity = @playlist.playlist_activities.last
    expect(playlist_activity.activity).to eq(@activity)
    expect(playlist_activity.position).to eq(1)
  end

  it "add_activity should use custom position when provided" do
    @playlist.save!
    @playlist.add_activity(@activity, position: 5)

    playlist_activity = @playlist.playlist_activities.last
    expect(playlist_activity.position).to eq(5)
  end

  it "add_activity should increment position when adding multiple activities" do
    @playlist.save!
    activity2 = Activity.create!(
      user: @user,
      name: "Second Activity",
      schedule_type: "flexible"
    )

    @playlist.add_activity(@activity)
    @playlist.add_activity(activity2)

    positions = @playlist.playlist_activities.pluck(:position).sort
    expect(positions).to eq([ 1, 2 ])
  end

  it "remove_activity should archive playlist_activity" do
    @playlist.save!
    playlist_activity = @playlist.playlist_activities.create!(
      activity: @activity,
      position: 1
    )

    expect(playlist_activity.archived_at).to be_nil
    @playlist.remove_activity(@activity)
    playlist_activity.reload
    expect(playlist_activity.archived_at).not_to be_nil
  end

  it "remove_activity should handle activity not in playlist" do
    @playlist.save!
    other_activity = Activity.create!(
      user: @user,
      name: "Other Activity",
      schedule_type: "flexible"
    )

    # Should not raise error
    expect { @playlist.remove_activity(other_activity) }.not_to raise_error
  end
end
