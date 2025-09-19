require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "should allow modern browsers" do
    get root_path
    assert_response :success
  end

  test "should inherit from ActionController::Base" do
    assert ApplicationController < ActionController::Base
  end
end
