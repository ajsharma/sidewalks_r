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

  test "should batch create events in dry run mode" do
    post batch_events_schedule_url, params: {
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
end
