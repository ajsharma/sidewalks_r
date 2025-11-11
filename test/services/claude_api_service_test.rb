require "test_helper"

class ClaudeApiServiceTest < ActiveSupport::TestCase
  def setup
    # AI config is loaded from config/ai.yml test environment
    # Set provider to anthropic for these tests
    @original_provider = AiConfig.instance.provider
    AiConfig.instance.provider = "anthropic"
    @service = ClaudeApiService.new
  end

  def teardown
    AiConfig.instance.provider = @original_provider
  end

  test "raises error when ANTHROPIC_API_KEY is not set" do
    # Temporarily override config to test error handling
    original_key = AiConfig.instance.anthropic_api_key
    AiConfig.instance.anthropic_api_key = nil

    error = assert_raises(ClaudeApiService::ApiError) do
      ClaudeApiService.new
    end

    assert_equal "ANTHROPIC_API_KEY not configured", error.message
  ensure
    AiConfig.instance.anthropic_api_key = original_key
  end

  test "extract_activity_from_text returns structured data" do
    stub_claude_api_success

    result = @service.extract_activity_from_text("Go hiking this weekend")

    assert_equal "Weekend Hiking", result["name"]
    assert_equal "flexible", result["schedule_type"]
    assert_equal 85, result["confidence_score"]
    assert_equal [ 6, 7 ], result["suggested_months"]
    assert_not_nil result["api_metadata"]
  end

  test "extract_activity_from_text handles API errors" do
    stub_claude_api_error(500)

    error = assert_raises(ClaudeApiService::ApiError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/API server error/, error.message)
  end

  test "extract_activity_from_text handles rate limit errors" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 429, body: { error: { message: "API rate limit exceeded" } }.to_json)

    error = assert_raises(ClaudeApiService::RateLimitError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/rate limit/, error.message)
  end

  test "extract_activity_from_text handles timeout" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_timeout

    error = assert_raises(ClaudeApiService::ApiError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/timed out|execution expired/, error.message)
  end

  test "extract_activity_from_url returns structured data with metadata" do
    stub_claude_api_success

    result = @service.extract_activity_from_url(
      url: "https://example.com/event",
      structured_data: { name: "Concert", description: "Music event" }
    )

    assert_equal "Weekend Hiking", result["name"]
    assert_not_nil result["api_metadata"]
  end

  test "validates response structure requires name" do
    stub_claude_api_response_without_required_fields

    error = assert_raises(ClaudeApiService::InvalidResponseError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/Missing required fields/, error.message)
  end

  test "validates schedule_type is valid" do
    stub_claude_api_with_invalid_schedule_type

    error = assert_raises(ClaudeApiService::InvalidResponseError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/Invalid schedule_type/, error.message)
  end

  test "validates confidence_score is in range" do
    stub_claude_api_with_invalid_confidence

    error = assert_raises(ClaudeApiService::InvalidResponseError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/Invalid confidence_score/, error.message)
  end

  test "parses JSON from markdown code blocks" do
    stub_claude_api_with_markdown_json

    result = @service.extract_activity_from_text("test input")

    assert_equal "Test Activity", result["name"]
    assert_equal 75, result["confidence_score"]
  end

  private

  def stub_claude_api_success
    response_body = {
      content: [
        {
          text: {
            name: "Weekend Hiking",
            description: "Enjoy nature on a hiking trail",
            schedule_type: "flexible",
            suggested_months: [ 6, 7 ],
            suggested_days_of_week: [ 0, 6 ],
            suggested_time_of_day: "morning",
            category_tags: [ "outdoor", "exercise" ],
            confidence_score: 85
          }.to_json
        }
      ],
      model: "claude-3-5-sonnet-20241022",
      usage: { input_tokens: 100, output_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_claude_api_error(status_code)
    error_body = {
      error: {
        message: "API error occurred"
      }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: status_code, body: error_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_claude_api_response_without_required_fields
    response_body = {
      content: [
        {
          text: {
            description: "Missing name field"
          }.to_json
        }
      ],
      model: "claude-3-5-sonnet-20241022",
      usage: { input_tokens: 100, output_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_claude_api_with_invalid_schedule_type
    response_body = {
      content: [
        {
          text: {
            name: "Test",
            schedule_type: "invalid_type",
            confidence_score: 85
          }.to_json
        }
      ],
      model: "claude-3-5-sonnet-20241022",
      usage: { input_tokens: 100, output_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_claude_api_with_invalid_confidence
    response_body = {
      content: [
        {
          text: {
            name: "Test",
            schedule_type: "flexible",
            confidence_score: 150
          }.to_json
        }
      ],
      model: "claude-3-5-sonnet-20241022",
      usage: { input_tokens: 100, output_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_claude_api_with_markdown_json
    json_content = {
      name: "Test Activity",
      schedule_type: "flexible",
      confidence_score: 75
    }

    response_body = {
      content: [
        {
          text: "```json\n#{json_content.to_json}\n```"
        }
      ],
      model: "claude-3-5-sonnet-20241022",
      usage: { input_tokens: 100, output_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end
end
