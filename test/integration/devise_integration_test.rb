require "test_helper"

class DeviseIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "devise pages render correctly" do
    # Sign in page
    get "/users/sign_in"
    assert_response :success
    assert_select "h2", text: "Sign in to your account"

    # Sign up page
    get "/users/sign_up"
    assert_response :success
    assert_select "h2", text: "Create your account"

    # Forgot password page
    get "/users/password/new"
    assert_response :success
    assert_select "h2", text: "Forgot your password?"
  end

  test "edit registration page renders when authenticated" do
    sign_in @user

    get "/users/edit"
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
