require "test_helper"

class AiActivityServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    ENV["ANTHROPIC_API_KEY"] = "test-key"
  end

  test "detects text input type" do
    service = AiActivityService.new(user: @user, input: "Go for a run")
    assert_equal :text, service.instance_variable_get(:@input_type)
  end

  test "detects url input type" do
    service = AiActivityService.new(user: @user, input: "https://example.com/event")
    assert_equal :url, service.instance_variable_get(:@input_type)
  end

  test "checks rate limits before processing" do
    # Create 20 suggestions in the last hour
    20.times do
      @user.ai_suggestions.create!(
        input_type: :text,
        input_text: "test",
        created_at: 30.minutes.ago
      )
    end

    service = AiActivityService.new(user: @user, input: "test")

    error = assert_raises(AiActivityService::RateLimitExceededError) do
      service.generate_suggestion
    end

    assert_match(/20 requests per hour/, error.message)
  end

  test "checks daily rate limits" do
    # Create 100 suggestions in the last day
    100.times do |i|
      @user.ai_suggestions.create!(
        input_type: :text,
        input_text: "test #{i}",
        created_at: (i * 10).minutes.ago
      )
    end

    service = AiActivityService.new(user: @user, input: "test")

    error = assert_raises(AiActivityService::RateLimitExceededError) do
      service.generate_suggestion
    end

    assert_match(/100 requests per day/, error.message)
  end

  test "generate_suggestion creates pending suggestion for text" do
    stub_successful_claude_api

    service = AiActivityService.new(user: @user, input: "Weekly team meeting")

    assert_difference "@user.ai_suggestions.count", 1 do
      suggestion = service.generate_suggestion

      assert_equal "text", suggestion.input_type
      assert_equal "Weekly team meeting", suggestion.input_text
      assert_equal "completed", suggestion.status
      assert_not_nil suggestion.suggested_data
    end
  end

  test "generate_suggestion marks failed on error" do
    stub_failing_claude_api

    service = AiActivityService.new(user: @user, input: "test")

    error = assert_raises(ClaudeApiService::ApiError) do
      service.generate_suggestion
    end

    suggestion = @user.ai_suggestions.last
    assert_equal "failed", suggestion.status
    assert_not_nil suggestion.error_message
  end

  test "accept_suggestion creates activity from suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    assert_difference "Activity.count", 1 do
      activity = AiActivityService.accept_suggestion(suggestion)

      assert activity.persisted?
      assert activity.ai_generated?
      assert_equal "Farmers Market Visit", activity.name
      assert_equal suggestion.user, activity.user
    end
  end

  test "accept_suggestion with user edits applies changes" do
    suggestion = ai_activity_suggestions(:text_completed)
    user_edits = {
      name: "My Custom Market Visit",
      description: "Custom description"
    }

    activity = AiActivityService.accept_suggestion(suggestion, user_edits: user_edits)

    assert_equal "My Custom Market Visit", activity.name
    assert_equal "Custom description", activity.description
  end

  test "accept_suggestion tracks user edits" do
    suggestion = ai_activity_suggestions(:text_completed)
    user_edits = {
      name: "Edited Name"
    }

    AiActivityService.accept_suggestion(suggestion, user_edits: user_edits)

    suggestion.reload
    assert_not_empty suggestion.user_edits
    assert_equal "Farmers Market Visit", suggestion.user_edits["name"]["original"]
    assert_equal "Edited Name", suggestion.user_edits["name"]["edited"]
  end

  test "accept_suggestion marks suggestion as accepted" do
    suggestion = ai_activity_suggestions(:text_completed)

    activity = AiActivityService.accept_suggestion(suggestion)

    suggestion.reload
    assert suggestion.accepted
    assert_not_nil suggestion.accepted_at
    assert_equal activity, suggestion.final_activity
  end

  test "build_activity_params extracts data correctly" do
    suggested_data = {
      "name" => "Test Activity",
      "description" => "Test description",
      "schedule_type" => "flexible",
      "suggested_months" => [ 6, 7, 8 ],
      "suggested_days_of_week" => [ 0, 6 ],
      "suggested_time_of_day" => "morning",
      "category_tags" => [ "outdoor" ]
    }

    params = AiActivityService.build_activity_params(suggested_data, {})

    assert_equal "Test Activity", params[:name]
    assert_equal "Test description", params[:description]
    assert_equal "flexible", params[:schedule_type]
    assert_equal [ 6, 7, 8 ], params[:suggested_months]
  end

  test "build_activity_params merges user edits" do
    suggested_data = { "name" => "Original", "description" => "Original desc" }
    user_edits = { "name" => "Edited" }

    params = AiActivityService.build_activity_params(suggested_data, user_edits)

    assert_equal "Edited", params[:name]
    assert_equal "Original desc", params[:description]
  end

  private

  def stub_successful_claude_api
    response_data = {
      "name" => "Weekly Team Meeting",
      "schedule_type" => "flexible",
      "confidence_score" => 80
    }

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 200,
        body: {
          content: [ { text: response_data.to_json } ],
          model: "claude-3-5-sonnet-20241022",
          usage: { input_tokens: 100, output_tokens: 150 }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_failing_claude_api
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 500, body: { error: { message: "API failed" } }.to_json)
  end
end
