require "test_helper"

class ActivitiesIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
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