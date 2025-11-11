require "test_helper"

class AiSuggestionGeneratorJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
    # Use Anthropic provider for these tests since they stub Claude API
    @original_provider = AiConfig.instance.provider
    AiConfig.instance.provider = "anthropic"
  end

  def teardown
    AiConfig.instance.provider = @original_provider
  end

  test "performs job and generates suggestion" do
    stub_successful_api

    assert_difference "@user.ai_suggestions.count", 1 do
      AiSuggestionGeneratorJob.perform_now(@user.id, "Go hiking", request_id: "test-123")
    end

    suggestion = @user.ai_suggestions.last
    assert_equal "completed", suggestion.status
  end

  test "handles API errors by marking suggestion as failed" do
    stub_failing_api

    # API errors should create a failed suggestion before re-raising
    begin
      AiSuggestionGeneratorJob.perform_now(@user.id, "test input", request_id: "test-123")
    rescue => e
      # Expected to raise for retry mechanism
    end

    # A failed suggestion should still be created
    failed_suggestion = @user.ai_suggestions.last
    assert_equal "failed", failed_suggestion.status
    assert_not_nil failed_suggestion.error_message
    assert_match(/API/, failed_suggestion.error_message)
  end

  private

  def stub_successful_api
    response = {
      "name" => "Hiking Trip",
      "schedule_type" => "flexible",
      "confidence_score" => 85,
      "api_metadata" => {
        "model" => "claude-3-5-sonnet-20241022",
        "usage" => { "input_tokens" => 100, "output_tokens" => 150 }
      }
    }

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 200,
        body: {
          content: [ { text: response.to_json } ],
          model: "claude-3-5-sonnet-20241022",
          usage: { input_tokens: 100, output_tokens: 150 }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_failing_api
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 500, body: { error: { message: "Server error" } }.to_json)
  end
end
