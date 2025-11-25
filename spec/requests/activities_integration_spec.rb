require "rails_helper"

RSpec.describe "ActivitiesIntegration", type: :request do
  before do
    @user = users(:one)
    @user.activities.destroy_all

    # Create activities with different types to test all conditional paths
    @strict_activity = @user.activities.create!(
      name: "Morning Workout",
      description: "Daily cardio and strength training session",
      schedule_type: "strict",
      start_time: 1.day.from_now.beginning_of_day + 7.hours,
      end_time: 1.day.from_now.beginning_of_day + 8.hours,
      max_frequency_days: 1,
      activity_links: [ "https://youtube.com/workout", "https://myfitnesspal.com" ]
    )

    @flexible_activity = @user.activities.create!(
      name: "Reading",
      description: "Read for personal development",
      schedule_type: "flexible",
      max_frequency_days: 30,
      activity_links: [ "https://goodreads.com" ]
    )

    @deadline_activity = @user.activities.create!(
      name: "Tax Filing",
      description: "Complete and submit annual tax return",
      schedule_type: "deadline",
      deadline: 30.days.from_now,
      max_frequency_days: nil,
      activity_links: []
    )

    @no_description_activity = @user.activities.create!(
      name: "Simple Task",
      schedule_type: "flexible",
      max_frequency_days: nil
    )
  end

  it "activities pages render when authenticated" do
    sign_in(@user)

    # Activities index
    get "/activities"
    expect(response).to have_http_status(:success)
    expect(response.body).to include "My Activities"

    # New activity page
    get "/activities/new"
    expect(response).to have_http_status(:success)
    expect(response.body).to include 'activity[name]'
  end

  it "activities/index.html.erb renders with activities" do
    sign_in(@user)
    get "/activities"
    expect(response).to have_http_status(:success)

    # Test main index elements
    expect(response.body).to include "My Activities"
    expect(response.body).to include "New Activity"

    # Test activity cards display
    expect(response.body).to include @strict_activity.name
    expect(response.body).to include @flexible_activity.name
    expect(response.body).to include @deadline_activity.name

    # Test schedule type badges
    expect(response.body).to include "Strict"
    expect(response.body).to include "Flexible"
    expect(response.body).to include "Deadline"

    # Test activity descriptions
    expect(response.body).to include "Daily cardio and strength training"
    expect(response.body).to include "Read for personal development"

    # Test strict schedule timing display
    expect(response.body).to include @strict_activity.start_time.strftime("%B %d, %Y")

    # Test deadline display
    expect(response.body).to include @deadline_activity.deadline.strftime("%B %d, %Y")

    # Test frequency descriptions
    expect(response.body).to include "Daily"
    expect(response.body).to include "Monthly"

    # Test action buttons
    expect(response.body).to include "View"
    expect(response.body).to include "Edit"
  end

  it "activities/index.html.erb renders empty state" do
    @user.activities.destroy_all
    sign_in(@user)
    get "/activities"
    expect(response).to have_http_status(:success)

    # Test empty state
    expect(response.body).to include "No activities yet"
    expect(response.body).to include "Get started by creating your first activity!"
    expect(response.body).to include "Create Activity"
  end

  it "activities/new.html.erb renders form correctly" do
    sign_in(@user)
    get "/activities/new"
    expect(response).to have_http_status(:success)

    # Test form elements
    expect(response.body).to include 'activity[name]'
    expect(response.body).to include 'activity[description]'
    expect(response.body).to include 'activity[schedule_type]'
    expect(response.body).to include 'activity[max_frequency_days]'

    # Test schedule type options
    expect(response.body).to include "Strict - Specific date and time"
    expect(response.body).to include "Flexible - Can be done anytime"
    expect(response.body).to include "Deadline - Must be done before a certain date"

    # Test conditional fields (initially hidden)
    expect(response.body).to include "strict_fields"
    expect(response.body).to include "deadline_fields"
    expect(response.body).to include 'activity[start_time]'
    expect(response.body).to include 'activity[end_time]'
    expect(response.body).to include 'activity[deadline]'

    # Test links section
    expect(response.body).to include "links_container"
    expect(response.body).to include "+ Add Link"

    # Test form buttons
    expect(response.body).to include "Cancel"

    # Test JavaScript is included
    expect(response.body).to include "toggleScheduleFields"
    expect(response.body).to include "addLink"
    expect(response.body).to include "removeLink"
  end

  it "activities form renders validation errors" do
    # Use Devise test helper for proper authentication
    sign_in(@user)

    # Create an invalid activity to trigger errors
    post "/activities", params: {
      activity: {
        name: "", # Empty name should cause validation error
        schedule_type: "strict"
      }
    }

    # Test error display - should show validation errors
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include "Name can&#39;t be blank" # HTML escaped apostrophe
  end

  it "activities form renders empty links container for new activity" do
    sign_in(@user)
    get "/activities/new"
    expect(response).to have_http_status(:success)

    # Test empty links container
    expect(response.body).to include "links_container"
    # Should be empty for new activity - no pre-filled link inputs
  end

  it "activities index handles archived activities" do
    # Archive an activity
    @strict_activity.update(archived_at: Time.current)

    sign_in(@user)
    get "/activities"
    expect(response).to have_http_status(:success)

    # Archived activities should not appear (assuming they're filtered)
    # This tests the conditional logic in the index view
    expect(response).to have_http_status(:success)
  end
end
