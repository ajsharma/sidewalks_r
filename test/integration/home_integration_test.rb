require "test_helper"

class HomeIntegrationTest < ActionDispatch::IntegrationTest
  test "home page renders" do
    get "/"
    assert_response :success
    assert_select "h1", text: "Home#index"
  end
end