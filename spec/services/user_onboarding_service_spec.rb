require "rails_helper"

RSpec.describe UserOnboardingService, type: :service do
  before do
    @user = users(:one)
    # Ensure user has no existing content
    @user.activities.destroy_all
    @user.playlists.destroy_all
  end

  it "populates starter content for new user" do
    expect {
      expect {
        UserOnboardingService.populate_starter_content(@user)
      }.to change { @user.playlists.count }.by(3)
    }.to change { @user.activities.count }.by(10)
  end

  it "does not populate content if user has activities" do
    @user.activities.create!(name: "Existing Activity", schedule_type: "flexible")

    expect {
      expect {
        UserOnboardingService.populate_starter_content(@user)
      }.not_to change { @user.playlists.count }
    }.not_to change { @user.activities.count }
  end

  it "does not populate content if user has playlists" do
    @user.playlists.create!(name: "Existing Playlist")

    expect {
      expect {
        UserOnboardingService.populate_starter_content(@user)
      }.not_to change { @user.playlists.count }
    }.not_to change { @user.activities.count }
  end

  it "load_onboarding_data returns valid hash" do
    data = UserOnboardingService.send(:load_onboarding_data)

    expect(data).to be_a Hash
    expect(data.keys).to include "activities"
    expect(data.keys).to include "playlists"
    expect(data["activities"]).to be_a Array
    expect(data["playlists"]).to be_a Array
  end

  it "create_activities creates activities with correct attributes" do
    activities_data = [
      {
        "name" => "Test Activity",
        "description" => "Test Description",
        "schedule_type" => "flexible",
        "max_frequency_days" => 1,
        "activity_links" => [ "https://example.com" ]
      }
    ]

    created_activities = UserOnboardingService.send(:create_activities, @user, activities_data)

    expect(created_activities.size).to eq 1
    activity = created_activities["Test Activity"]
    expect(activity.name).to eq "Test Activity"
    expect(activity.description).to eq "Test Description"
    expect(activity.schedule_type).to eq "flexible"
    expect(activity.max_frequency_days).to eq 1
    expect(activity.activity_links).to eq [ "https://example.com" ]
  end

  it "create_playlists creates playlists with activities" do
    # First create some activities
    activity = @user.activities.create!(name: "Test Activity", schedule_type: "flexible")
    created_activities = { "Test Activity" => activity }

    playlists_data = [
      {
        "name" => "Test Playlist",
        "description" => "Test Description",
        "activities" => [ "Test Activity" ]
      }
    ]

    UserOnboardingService.send(:create_playlists, @user, playlists_data, created_activities)

    playlist = @user.playlists.find_by(name: "Test Playlist")
    expect(playlist).not_to be_nil
    expect(playlist.description).to eq "Test Description"
    expect(playlist.playlist_activities.count).to eq 1
    expect(playlist.activities.first).to eq activity
  end

  it "parse_datetime handles nil and blank strings" do
    expect(UserOnboardingService.send(:parse_datetime, nil)).to be_nil
    expect(UserOnboardingService.send(:parse_datetime, "")).to be_nil
    expect(UserOnboardingService.send(:parse_datetime, "   ")).to be_nil
  end

  it "parse_datetime handles absolute times" do
    result = UserOnboardingService.send(:parse_datetime, "2024-01-01 10:00")
    expect(result).to respond_to :year
  end

  it "parse_datetime handles relative times" do
    result = UserOnboardingService.send(:parse_datetime, "+1.day 10:00")
    expect(result).to respond_to :year

    result = UserOnboardingService.send(:parse_datetime, "+5.days 17:00")
    expect(result).to respond_to :year
  end

  it "parse_datetime handles invalid input gracefully" do
    result = UserOnboardingService.send(:parse_datetime, "invalid-date")
    expect(result).to be_nil
  end

  it "parse_relative_datetime correctly calculates future time" do
    freeze_time = Time.zone.parse("2024-01-01 00:00:00")
    travel_to(freeze_time) do
      result = UserOnboardingService.send(:parse_relative_datetime, "+2.days 15:30")
      expected = freeze_time.beginning_of_day + 2.days + 15.hours + 30.minutes
      expect(result).to eq expected
    end
  end

  it "parse_relative_datetime handles invalid format" do
    result = UserOnboardingService.send(:parse_relative_datetime, "invalid format")
    expect(result).to be_nil
  end
end
