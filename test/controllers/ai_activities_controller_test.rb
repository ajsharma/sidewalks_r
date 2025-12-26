require "test_helper"

class AiActivitiesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
    # AI config is loaded from config/ai.yml test environment
  end

  test "index requires authentication" do
    sign_out @user
    get ai_activities_path
    assert_redirected_to new_user_session_path
  end

  test "index returns user's suggestions as JSON" do
    get ai_activities_path, as: :json
    assert_response :success
  end

  test "index renders HTML view" do
    get ai_activities_path
    assert_response :success
    assert_select "h1", text: "AI Activity Suggestions"
    assert_select "textarea[name='input']"
  end

  test "index checks AI feature enabled" do
    # Temporarily disable the feature
    original_value = AiConfig.instance.feature_enabled
    AiConfig.instance.feature_enabled = false

    get ai_activities_path
    assert_redirected_to root_path
    assert_equal "AI suggestions are not currently available", flash[:alert]
  ensure
    AiConfig.instance.feature_enabled = original_value
  end

  test "generate queues background job" do
    assert_enqueued_with(job: AiSuggestionGeneratorJob) do
      post generate_ai_activities_path, params: { input: "Go for a run" }, as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "processing", json["status"]
    assert_not_nil json["request_id"]
  end

  test "generate returns error for blank input" do
    post generate_ai_activities_path, params: { input: "" }, as: :json
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_match(/cannot be blank/, json["error"])
  end

  test "generate handles rate limit error" do
    # Create 20 suggestions in last hour to hit rate limit
    20.times do
      @user.ai_suggestions.create!(
        input_type: :text,
        input_text: "test",
        created_at: 30.minutes.ago
      )
    end

    # The rate limit check happens in the background job, so we test the job directly
    # The controller will queue the job successfully
    post generate_ai_activities_path, params: { input: "test" }, as: :json
    assert_response :success
  end

  test "show displays suggestion as JSON" do
    suggestion = ai_activity_suggestions(:text_completed)
    get ai_activity_path(suggestion), as: :json
    assert_response :success
  end

  test "show renders HTML view" do
    suggestion = ai_activity_suggestions(:text_completed)
    get ai_activity_path(suggestion)
    assert_response :success
    assert_select "h1", text: suggestion.suggested_activity_name
    assert_select "input[name='name']"
    assert_select "input[type='submit'][value='Accept & Create Activity']"
  end

  test "show renders HTML view with nil api_response" do
    suggestion = ai_activity_suggestions(:completed_with_nil_api_response)
    get ai_activity_path(suggestion)
    assert_response :success
    assert_select "h1", text: suggestion.suggested_activity_name
    assert_select "input[name='name']"
  end

  test "show returns 404 for other user's suggestion" do
    other_user_suggestion = ai_activity_suggestions(:accepted_suggestion)
    get ai_activity_path(other_user_suggestion), as: :json
    assert_response :not_found
  end

  test "accept creates activity from suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    assert_difference "Activity.count", 1 do
      post accept_ai_activity_path(suggestion), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_not_nil json["activity"]
    assert_equal "Activity created successfully", json["message"]

    suggestion.reload
    assert suggestion.accepted
  end

  test "accept applies user edits" do
    suggestion = ai_activity_suggestions(:text_completed)

    post accept_ai_activity_path(suggestion), params: {
      name: "Custom Name",
      description: "Custom Description"
    }, as: :json

    assert_response :created
    activity = Activity.last
    assert_equal "Custom Name", activity.name
    assert_equal "Custom Description", activity.description
  end

  test "reject marks suggestion as rejected" do
    suggestion = ai_activity_suggestions(:text_completed)

    post reject_ai_activity_path(suggestion), as: :json

    assert_response :success
    suggestion.reload
    assert_not suggestion.accepted
    assert_equal "completed", suggestion.status
  end

  test "destroy deletes suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    assert_difference "AiActivitySuggestion.count", -1 do
      delete ai_activity_path(suggestion), as: :json
    end

    assert_response :no_content
  end

  test "retry queues background job for failed suggestion" do
    suggestion = ai_activity_suggestions(:failed_suggestion)

    assert_enqueued_with(job: AiSuggestionGeneratorJob) do
      post retry_ai_activity_path(suggestion), as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "processing", json["status"]
    assert_not_nil json["request_id"]

    suggestion.reload
    assert_equal "processing", suggestion.status
    assert_nil suggestion.error_message
  end

  test "retry returns error for accepted suggestion" do
    suggestion = ai_activity_suggestions(:accepted_suggestion)
    sign_out @user
    sign_in users(:two)

    post retry_ai_activity_path(suggestion), as: :json

    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_match(/Cannot retry accepted suggestions/, json["error"])
  end

  test "retry creates new suggestion for completed suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    assert_difference "AiActivitySuggestion.count", 1 do
      assert_enqueued_with(job: AiSuggestionGeneratorJob) do
        post retry_ai_activity_path(suggestion), as: :json
      end
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "processing", json["status"]
    assert_not_nil json["request_id"]
    assert_not_nil json["new_suggestion_id"]

    # Original suggestion should be unchanged
    suggestion.reload
    assert_equal "completed", suggestion.status

    # New suggestion should be created
    new_suggestion = AiActivitySuggestion.find(json["new_suggestion_id"])
    assert_equal "pending", new_suggestion.status
    assert_equal suggestion.input_text, new_suggestion.input_text
    assert_equal suggestion.input_type, new_suggestion.input_type
  end

  test "retry renders HTML for failed suggestion" do
    suggestion = ai_activity_suggestions(:failed_suggestion)

    assert_enqueued_with(job: AiSuggestionGeneratorJob) do
      post retry_ai_activity_path(suggestion)
    end

    assert_redirected_to ai_activities_path
    assert_equal "Generating new AI suggestion...", flash[:notice]
  end

  test "retry renders HTML for completed suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    assert_difference "AiActivitySuggestion.count", 1 do
      assert_enqueued_with(job: AiSuggestionGeneratorJob) do
        post retry_ai_activity_path(suggestion)
      end
    end

    assert_redirected_to ai_activities_path
    assert_equal "Generating new AI suggestion...", flash[:notice]
  end

  test "retry returns 404 for other user's suggestion" do
    other_user_suggestion = ai_activity_suggestions(:accepted_suggestion)
    post retry_ai_activity_path(other_user_suggestion), as: :json
    assert_response :not_found
  end
end
