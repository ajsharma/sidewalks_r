require "test_helper"

class UserOnboardingServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    # Ensure user has no existing content
    @user.activities.destroy_all
    @user.playlists.destroy_all
  end

  test "populates starter content for new user" do
    assert_difference "@user.activities.count", 10 do
      assert_difference "@user.playlists.count", 3 do
        UserOnboardingService.populate_starter_content(@user)
      end
    end
  end

  test "does not populate content if user has activities" do
    @user.activities.create!(name: "Existing Activity", schedule_type: "flexible")

    assert_no_difference "@user.activities.count" do
      assert_no_difference "@user.playlists.count" do
        UserOnboardingService.populate_starter_content(@user)
      end
    end
  end

  test "does not populate content if user has playlists" do
    @user.playlists.create!(name: "Existing Playlist")

    assert_no_difference "@user.activities.count" do
      assert_no_difference "@user.playlists.count" do
        UserOnboardingService.populate_starter_content(@user)
      end
    end
  end

  test "load_onboarding_data returns valid hash" do
    data = UserOnboardingService.send(:load_onboarding_data)

    assert_instance_of Hash, data
    assert_includes data.keys, "activities"
    assert_includes data.keys, "playlists"
    assert_instance_of Array, data["activities"]
    assert_instance_of Array, data["playlists"]
  end

  test "create_activities creates activities with correct attributes" do
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

    assert_equal 1, created_activities.size
    activity = created_activities["Test Activity"]
    assert_equal "Test Activity", activity.name
    assert_equal "Test Description", activity.description
    assert_equal "flexible", activity.schedule_type
    assert_equal 1, activity.max_frequency_days
    assert_equal [ "https://example.com" ], activity.activity_links
  end

  test "create_playlists creates playlists with activities" do
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
    assert_not_nil playlist
    assert_equal "Test Description", playlist.description
    assert_equal 1, playlist.playlist_activities.count
    assert_equal activity, playlist.activities.first
  end

  test "parse_datetime handles nil and blank strings" do
    assert_nil UserOnboardingService.send(:parse_datetime, nil)
    assert_nil UserOnboardingService.send(:parse_datetime, "")
    assert_nil UserOnboardingService.send(:parse_datetime, "   ")
  end

  test "parse_datetime handles absolute times" do
    result = UserOnboardingService.send(:parse_datetime, "2024-01-01 10:00")
    assert result.respond_to?(:year)
  end

  test "parse_datetime handles relative times" do
    result = UserOnboardingService.send(:parse_datetime, "+1.day 10:00")
    assert result.respond_to?(:year)

    result = UserOnboardingService.send(:parse_datetime, "+5.days 17:00")
    assert result.respond_to?(:year)
  end

  test "parse_datetime handles invalid input gracefully" do
    result = UserOnboardingService.send(:parse_datetime, "invalid-date")
    assert_nil result
  end

  test "parse_relative_datetime correctly calculates future time" do
    freeze_time = Time.zone.parse("2024-01-01 00:00:00")
    travel_to(freeze_time) do
      result = UserOnboardingService.send(:parse_relative_datetime, "+2.days 15:30")
      expected = freeze_time.beginning_of_day + 2.days + 15.hours + 30.minutes
      assert_equal expected, result
    end
  end

  test "parse_relative_datetime handles invalid format" do
    result = UserOnboardingService.send(:parse_relative_datetime, "invalid format")
    assert_nil result
  end
end
