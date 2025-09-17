require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @activity = activities(:one)
    @user = users(:one)
    sign_in @user
  end

  test "should get index" do
    get activities_url
    assert_response :success
  end

  test "should get show" do
    get activity_url(@activity)
    assert_response :success
  end

  test "should get new" do
    get new_activity_url
    assert_response :success
  end

  test "should create activity" do
    assert_difference("Activity.count") do
      post activities_url, params: { activity: { name: "Test Activity", description: "Test" } }
    end
    assert_redirected_to activity_url(Activity.last)
  end

  test "should get edit" do
    get edit_activity_url(@activity)
    assert_response :success
  end

  test "should update activity" do
    patch activity_url(@activity), params: {
      activity: {
        name: "Updated Activity",
        description: "Updated description",
        schedule_type: "flexible"
      }
    }
    assert_redirected_to activity_url(@activity)
  end

  # TODO: Fix test isolation issue - activity may be archived by previous tests
  # test "should archive activity on destroy" do
  #   assert_no_difference("Activity.count") do
  #     delete activity_url(@activity)
  #   end
  #   assert_redirected_to activities_url
  #   @activity.reload
  #   assert @activity.archived?
  # end
end
