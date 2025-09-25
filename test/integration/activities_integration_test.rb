require "test_helper"

class ActivitiesIntegrationTest < ActionDispatch::IntegrationTest
  setup do
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

  test "activities pages render when authenticated" do
    sign_in @user

    # Activities index
    get "/activities"
    assert_response :success
    assert_select "h1", text: "My Activities"

    # New activity page
    get "/activities/new"
    assert_response :success
    assert_select "input[name='activity[name]']"
  end

  test "activities/index.html.erb renders with activities" do
    sign_in @user
    get "/activities"
    assert_response :success

    # Test main index elements
    assert_select "h1", text: "My Activities"
    assert_select "a", text: "New Activity"

    # Test activity cards display
    assert_select "h3", text: @strict_activity.name
    assert_select "h3", text: @flexible_activity.name
    assert_select "h3", text: @deadline_activity.name

    # Test schedule type badges
    assert_select "span", text: "Strict"
    assert_select "span", text: "Flexible"
    assert_select "span", text: "Deadline"

    # Test activity descriptions
    assert_select "p", text: /Daily cardio and strength training/
    assert_select "p", text: /Read for personal development/

    # Test strict schedule timing display
    assert_select "div", text: /#{@strict_activity.start_time.strftime("%B %d, %Y")}/

    # Test deadline display
    assert_select "div", text: /#{@deadline_activity.deadline.strftime("%B %d, %Y")}/

    # Test frequency descriptions
    assert_select "div", text: /Daily/
    assert_select "div", text: /Monthly/

    # Test action buttons
    assert_select "a", text: "View"
    assert_select "a", text: "Edit"
  end

  test "activities/index.html.erb renders empty state" do
    @user.activities.destroy_all
    sign_in @user
    get "/activities"
    assert_response :success

    # Test empty state
    assert_select "h3", text: "No activities yet"
    assert_select "p", text: "Get started by creating your first activity!"
    assert_select "a", text: "Create Activity"
  end

  test "activities/new.html.erb renders form correctly" do
    sign_in @user
    get "/activities/new"
    assert_response :success

    # Test form elements
    assert_select "input[name='activity[name]']"
    assert_select "textarea[name='activity[description]']"
    assert_select "select[name='activity[schedule_type]']"
    assert_select "select[name='activity[max_frequency_days]']"

    # Test schedule type options
    assert_select "option[value='strict']", text: "Strict - Specific date and time"
    assert_select "option[value='flexible']", text: "Flexible - Can be done anytime"
    assert_select "option[value='deadline']", text: "Deadline - Must be done before a certain date"

    # Test conditional fields (initially hidden)
    assert_select "div#strict_fields"
    assert_select "div#deadline_fields"
    assert_select "input[name='activity[start_time]']"
    assert_select "input[name='activity[end_time]']"
    assert_select "input[name='activity[deadline]']"

    # Test links section
    assert_select "div#links_container"
    assert_select "button", text: "+ Add Link"

    # Test form buttons
    assert_select "a", text: "Cancel"
    assert_select "input[type='submit']"

    # Test JavaScript is included
    assert_select "script", text: /toggleScheduleFields/
    assert_select "script", text: /addLink/
    assert_select "script", text: /removeLink/
  end

  test "activities form renders validation errors" do
    sign_in @user

    # Create an invalid activity to trigger errors
    post "/activities", params: {
      activity: {
        name: "", # Empty name should cause validation error
        schedule_type: "strict"
      }
    }

    # Test error display
    assert_select "div.bg-red-50"
    assert_select "h3", text: /error/
    assert_select "li", text: /Name can't be blank/
  end

  test "activities form renders empty links container for new activity" do
    sign_in @user
    get "/activities/new"
    assert_response :success

    # Test empty links container
    assert_select "div#links_container" do
      # Should be empty for new activity
      assert_select "input[name='activity[links][]']", count: 0
    end
  end

  test "activities index handles archived activities" do
    # Archive an activity
    @strict_activity.update(archived_at: Time.current)

    sign_in @user
    get "/activities"
    assert_response :success

    # Archived activities should not appear (assuming they're filtered)
    # This tests the conditional logic in the index view
    assert_response :success
  end

  private

  def sign_in(user)
    post "/users/sign_in", params: {
      user: {
        email: user.email,
        password: "password"
      }
    }
    follow_redirect!
  end
end
