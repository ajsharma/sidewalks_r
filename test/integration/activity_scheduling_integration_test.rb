require "test_helper"

class ActivitySchedulingIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "schedule page renders when authenticated" do
    sign_in @user

    get "/schedule"
    assert_response :success
    assert_select "h1", text: "Activity Scheduling"

    # Test with date parameters
    get "/schedule", params: { start_date: Date.current, end_date: Date.current + 1.week }
    assert_response :success

    # Test preview functionality (dry run)
    post "/schedule", params: { dry_run: true, start_date: Date.current, end_date: Date.current + 1.week }
    assert_response :success
    assert_select "h1", text: "Calendar Events Preview"
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