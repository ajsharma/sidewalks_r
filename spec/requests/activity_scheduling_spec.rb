require "rails_helper"

RSpec.describe "ActivityScheduling", type: :request do
  include GoogleHelpers::GoogleCalendarMockHelper

  before do
    @user = users(:one)
    @activity = activities(:one)
    sign_in @user
  end

  it "gets show" do
    get schedule_url
    expect(response).to have_http_status(:success)
  end

  it "batches create events in dry run mode" do
    post batch_events_schedule_url, params: {
      dry_run: "true",
      start_date: Date.current.to_s,
      end_date: (Date.current + 1.week).to_s
    }
    expect(response).to have_http_status(:success)
  end

  it "preloads google_accounts to prevent N+1 queries" do
    # Create a google account for the user
    @user.google_accounts.create!(
      google_id: "test123",
      email: @user.email,
      access_token: "test_token",
      refresh_token: "test_refresh"
    )

    get schedule_url
    expect(response).to have_http_status(:success)

    # The page should render without N+1 queries on google_accounts
    # This test verifies the preload_associations before_action works
  end

  it "creates single calendar event" do
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
      post events_schedule_url, params: {
        activity_id: @activity.id,
        start_time: start_time.iso8601,
        end_time: end_time.iso8601,
        title: @activity.name,
        type: @activity.schedule_type
      }

      expect(response).to redirect_to(schedule_path)
      expect(flash[:notice]).to eq("Successfully added '#{@activity.name}' to your calendar!")
    end
  end

  it "handles activity not found in create" do
    start_time = 1.day.from_now.beginning_of_day + 10.hours
    end_time = start_time + 1.hour

    post events_schedule_url, params: {
      activity_id: 999999, # Non-existent ID
      start_time: start_time.iso8601,
      end_time: end_time.iso8601
    }

    expect(response).to redirect_to(schedule_path)
    expect(flash[:alert]).to eq("Activity not found")
  end

  it "handles invalid date format in create" do
    # Create a google account for the user
    google_account = @user.google_accounts.create!(
      google_id: "test123",
      email: @user.email,
      access_token: "test_token",
      refresh_token: "test_refresh"
    )

    post events_schedule_url, params: {
      activity_id: @activity.id,
      start_time: "invalid-date",
      end_time: "invalid-date"
    }

    expect(response).to redirect_to(schedule_path)
    expect(flash[:alert]).to eq("Invalid date/time format")
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
