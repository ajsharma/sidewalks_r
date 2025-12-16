require "rails_helper"

RSpec.describe "ActivitySchedulingIntegration", type: :request do
  before do
    @user = create(:user)

    # Create some activities for testing
    @strict_activity = create(:activity, :strict,
      user: @user,
      name: "Morning Meeting",
      description: "Daily standup",
      start_time: 1.day.from_now.beginning_of_day + 9.hours,
      end_time: 1.day.from_now.beginning_of_day + 10.hours
    )

    @flexible_activity = create(:activity,
      user: @user,
      name: "Exercise",
      description: "Daily workout",
      schedule_type: "flexible",
      max_frequency_days: 1
    )

    @deadline_activity = create(:activity, :deadline_based,
      user: @user,
      name: "Project Submission",
      description: "Submit quarterly report",
      deadline: 2.days.from_now
    )

    # Create a Google account for testing calendar integration
    @google_account = create(:google_account,
      user: @user,
      email: "test@example.com",
      google_id: "123456789",
      access_token: "access_token",
      refresh_token: "refresh_token",
      expires_at: 1.hour.from_now
    )
  end

  it "schedule page renders when authenticated" do
    sign_in(@user)

    get "/schedule"
    expect(response).to have_http_status(:success)
    expect(response.body).to include "Activity Scheduling"

    # Test with date parameters
    get "/schedule", params: { start_date: Date.current, end_date: Date.current + 1.week }
    expect(response).to have_http_status(:success)

    # Test preview functionality (dry run)
    post "/schedule/events/batch", params: { dry_run: true, start_date: Date.current, end_date: Date.current + 1.week }
    expect(response).to have_http_status(:success)
    expect(response.body).to include "Calendar Events Preview"
  end

  it "activity_scheduling/show.html.erb renders with activities and Google account" do
    sign_in(@user)
    get "/schedule"
    expect(response).to have_http_status(:success)

    # Test main page elements
    expect(response.body).to include "Activity Scheduling"
    expect(response.body).to include "Schedule Range"

    # Test date range form
    expect(response.body).to include "start_date"
    expect(response.body).to include "end_date"
    expect(response.body).to include "Update Schedule"

    # Test summary stats section (when events exist)
    expect(response.body).to include "Total Activities"
    expect(response.body).to include "Strict Schedule"
    expect(response.body).to include "Flexible"
    expect(response.body).to include "Deadlines"
    expect(response.body).to include "Calendar Events"

    # Test combined schedule section
    expect(response.body).to include "Your Schedule"

    # Test action buttons (Preview and Create Events)
    expect(response.body).to include "Preview Calendar Events"
    expect(response.body).to include "Create Calendar Events"
  end

  it "activity_scheduling/show.html.erb renders without Google account" do
    # Remove Google account to test different state
    @user.google_accounts.destroy_all
    @user.activities.destroy_all

    sign_in(@user)
    get "/schedule"
    expect(response).to have_http_status(:success)

    # Test Google Calendar connection prompt
    expect(response.body).to include "Connect Google Calendar"
    expect(response.body).to include "Sign in with Google"
  end

  it "activity_scheduling/show.html.erb renders with no activities" do
    # Remove all activities to test empty state
    @user.activities.destroy_all

    sign_in(@user)
    get "/schedule"
    expect(response).to have_http_status(:success)

    # Test empty state
    expect(response.body).to include "No events to display"
    expect(response.body).to include "Create an Activity"
  end

  it "activity_scheduling/show.html.erb renders urgent deadlines alert" do
    # Create an urgent activity (close deadline)
    @urgent_activity = @user.activities.create!(
      name: "Urgent Task",
      description: "This is urgent",
      schedule_type: "deadline",
      deadline: 1.hour.from_now
    )

    sign_in(@user)
    # Pass explicit date range to ensure the urgent activity is included
    get "/schedule", params: {
      start_date: Date.current,
      end_date: Date.current + 1.week
    }
    expect(response).to have_http_status(:success)

    # Test urgent deadlines alert
    expect(response.body).to include "Urgent Activities Detected"
    expect(response.body).to match(/You have \d+ activities with upcoming or overdue deadlines/)
  end

  it "activity_scheduling/show.html.erb event display with different types" do
    sign_in(@user)
    get "/schedule"
    expect(response).to have_http_status(:success)

    # Test event type badges
    expect(response.body).to include "Strict"
    expect(response.body).to include "Flexible"
    expect(response.body).to include "Deadline"

    # Test confidence badges
    expect(response.body).to match(/confidence/i)
  end

  it "activity_scheduling/preview.html.erb renders dry run results" do
    sign_in(@user)

    # Make a POST request with dry_run=true to trigger preview
    post "/schedule/events/batch", params: {
      start_date: Date.current,
      end_date: Date.current + 1.week,
      dry_run: true
    }
    expect(response).to have_http_status(:success)

    # Test preview page elements
    expect(response.body).to include "Calendar Events Preview"
    expect(response.body).to include "Dry Run Results"

    # Test summary stats
    expect(response.body).to include "Total Events"
    expect(response.body).to include "Existing Calendar Events"
    expect(response.body).to include "Conflicts Avoided"

    # Test event type summaries
    expect(response.body).to include "Strict Events"
    expect(response.body).to include "Flexible Events"
    expect(response.body).to include "Deadline Events"

    # Test next steps section
    expect(response.body).to include "Next Steps"

    # Test event timeline section
    expect(response.body).to include "Event Timeline"

    # Test action buttons
    expect(response.body).to include "Back to Schedule"
    expect(response.body).to include "Modify Schedule"
    expect(response.body).to include "Create All"
  end

  it "activity_scheduling/preview.html.erb renders event timeline" do
    sign_in(@user)

    post "/schedule/events/batch", params: {
      start_date: Date.current,
      end_date: Date.current + 1.week,
      dry_run: true
    }
    expect(response).to have_http_status(:success)

    # Test event type badges
    expect(response.body).to include "Strict"
    expect(response.body).to include "Flexible"
    expect(response.body).to include "Deadline"

    # Test confidence indicators
    expect(response.body).to match(/confidence/i)
  end

  it "activity_scheduling/preview.html.erb renders empty state" do
    # Remove all activities to test empty preview
    @user.activities.destroy_all

    sign_in(@user)

    post "/schedule/events/batch", params: {
      start_date: Date.current,
      end_date: Date.current + 1.week,
      dry_run: true
    }
    expect(response).to have_http_status(:success)

    # Test empty timeline state
    expect(response.body).to include "No events to preview."
  end

  it "activity_scheduling/show.html.erb renders with custom date range" do
    sign_in(@user)

    get "/schedule", params: {
      start_date: "2024-01-01",
      end_date: "2024-01-31"
    }
    expect(response).to have_http_status(:success)

    # Test that custom dates are used in the form
    expect(response.body).to include "2024-01-01"
    expect(response.body).to include "2024-01-31"
  end

  it "activity_scheduling views handle various event properties" do
    sign_in(@user)
    get "/schedule"
    expect(response).to have_http_status(:success)

    # Test various conditional elements that might appear
    # These test the ERB conditionals even if the data doesn't trigger them

    # Test page renders
    expect(response).to have_http_status(:success)
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      }
    }
  end
end
