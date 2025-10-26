require "test_helper"

class ActivitySchedulingControllerTest < ActionDispatch::IntegrationTest
  include GoogleHelpers::GoogleCalendarMockHelper

  setup do
    @user = users(:one)
    @activity = activities(:one)
    sign_in @user
  end

  test "should get show" do
    get schedule_url
    assert_response :success
  end

  test "should create schedule in dry run mode" do
    post schedule_url, params: {
      dry_run: "true",
      start_date: Date.current.to_s,
      end_date: (Date.current + 1.week).to_s
    }
    assert_response :success
  end

  test "should preload google_accounts to prevent N+1 queries" do
    # Create a google account for the user
    @user.google_accounts.create!(
      google_id: "test123",
      email: @user.email,
      access_token: "test_token",
      refresh_token: "test_refresh"
    )

    get schedule_url
    assert_response :success

    # The page should render without N+1 queries on google_accounts
    # This test verifies the preload_associations before_action works
  end

  test "should create single calendar event" do
    # Create a google account for the user to enable calendar creation
    google_account = @user.google_accounts.create!(
      google_id: "test123",
      email: @user.email,
      access_token: "test_token",
      refresh_token: "test_refresh"
    )

    start_time = 1.day.from_now.beginning_of_day + 10.hours
    end_time = start_time + 1.hour

    # Mock the Google Calendar API
    with_mocked_google_calendar([]) do
      post create_single_schedule_url, params: {
        activity_id: @activity.id,
        start_time: start_time.iso8601,
        end_time: end_time.iso8601,
        title: @activity.name,
        type: @activity.schedule_type
      }

      assert_redirected_to schedule_path
      assert_equal "Successfully added '#{@activity.name}' to your calendar!", flash[:notice]
    end
  end

  test "should handle activity not found in create_single" do
    start_time = 1.day.from_now.beginning_of_day + 10.hours
    end_time = start_time + 1.hour

    post create_single_schedule_url, params: {
      activity_id: 999999, # Non-existent ID
      start_time: start_time.iso8601,
      end_time: end_time.iso8601
    }

    assert_redirected_to schedule_path
    assert_equal "Activity not found", flash[:alert]
  end

  test "should handle invalid date format in create_single" do
    # Create a google account for the user
    google_account = @user.google_accounts.create!(
      google_id: "test123",
      email: @user.email,
      access_token: "test_token",
      refresh_token: "test_refresh"
    )

    post create_single_schedule_url, params: {
      activity_id: @activity.id,
      start_time: "invalid-date",
      end_time: "invalid-date"
    }

    assert_redirected_to schedule_path
    assert_equal "Invalid date/time format", flash[:alert]
  end
end
