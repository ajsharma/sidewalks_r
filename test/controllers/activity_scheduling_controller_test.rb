require "test_helper"

class ActivitySchedulingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @activity = activities(:one)
    sign_in @user
  end

  test "should get show" do
    get schedule_url
    assert_response :success
  end

  # TODO: Fix activity scheduling test - causes cookie overflow
  # test "should create schedule in dry run mode" do
  #   post schedule_url, params: {
  #     dry_run: "true",
  #     start_date: Date.current.to_s,
  #     end_date: (Date.current + 1.week).to_s
  #   }
  #   assert_response :success
  # end
end
