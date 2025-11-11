require "test_helper"

class OpenAiServiceTest < ActiveSupport::TestCase
  def setup
    # AI config is loaded from config/ai.yml test environment
    @service = OpenAiService.new
  end

  test "raises error when OPENAI_API_KEY is not set" do
    # Temporarily override config to test error handling
    original_key = AiConfig.instance.openai_api_key
    AiConfig.instance.openai_api_key = nil

    error = assert_raises(OpenAiService::ApiError) do
      OpenAiService.new
    end

    assert_equal "OPENAI_API_KEY not configured", error.message
  ensure
    AiConfig.instance.openai_api_key = original_key
  end

  test "extract_activity_from_text returns structured data" do
    stub_openai_api_success

    result = @service.extract_activity_from_text("Go hiking this weekend")

    assert_equal "Weekend Hiking", result["name"]
    assert_equal "flexible", result["schedule_type"]
    assert_equal 85, result["confidence_score"]
    assert_equal [ 6, 7 ], result["suggested_months"]
    assert_not_nil result["api_metadata"]
  end

  test "extract_activity_from_text handles API errors" do
    stub_openai_api_error(500)

    error = assert_raises(OpenAiService::ApiError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/API request failed/, error.message)
  end

  test "extract_activity_from_text handles rate limit errors" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 429, body: { error: { message: "Rate limit exceeded" } }.to_json)

    error = assert_raises(OpenAiService::RateLimitError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/rate limit/, error.message)
  end

  test "extract_activity_from_text handles timeout" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_timeout

    error = assert_raises(OpenAiService::ApiError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/API request failed/, error.message)
  end

  test "extract_activity_from_url returns structured data with metadata" do
    stub_openai_api_success

    result = @service.extract_activity_from_url(
      url: "https://example.com/event",
      structured_data: { name: "Concert", description: "Music event" }
    )

    assert_equal "Weekend Hiking", result["name"]
    assert_not_nil result["api_metadata"]
  end

  test "validates response structure requires name" do
    stub_openai_api_response_without_required_fields

    error = assert_raises(OpenAiService::InvalidResponseError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/Missing required fields/, error.message)
  end

  test "validates schedule_type is valid" do
    stub_openai_api_with_invalid_schedule_type

    error = assert_raises(OpenAiService::InvalidResponseError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/Invalid schedule_type/, error.message)
  end

  test "validates confidence_score is in range" do
    stub_openai_api_with_invalid_confidence

    error = assert_raises(OpenAiService::InvalidResponseError) do
      @service.extract_activity_from_text("test input")
    end

    assert_match(/Invalid confidence_score/, error.message)
  end

  test "parses JSON from markdown code blocks" do
    stub_openai_api_with_markdown_json

    result = @service.extract_activity_from_text("test input")

    assert_equal "Test Activity", result["name"]
    assert_equal 75, result["confidence_score"]
  end

  private

  def stub_openai_api_success
    response_body = {
      choices: [
        {
          message: {
            content: {
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
        }
      ],
      model: "gpt-4o",
      usage: { prompt_tokens: 100, completion_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_openai_api_error(status_code)
    error_body = {
      error: {
        message: "API error occurred"
      }
    }.to_json

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: status_code, body: error_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_openai_api_response_without_required_fields
    response_body = {
      choices: [
        {
          message: {
            content: {
              description: "Missing name field"
            }.to_json
          }
        }
      ],
      model: "gpt-4o",
      usage: { prompt_tokens: 100, completion_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_openai_api_with_invalid_schedule_type
    response_body = {
      choices: [
        {
          message: {
            content: {
              name: "Test",
              schedule_type: "invalid_type",
              confidence_score: 85
            }.to_json
          }
        }
      ],
      model: "gpt-4o",
      usage: { prompt_tokens: 100, completion_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_openai_api_with_invalid_confidence
    response_body = {
      choices: [
        {
          message: {
            content: {
              name: "Test",
              schedule_type: "flexible",
              confidence_score: 150
            }.to_json
          }
        }
      ],
      model: "gpt-4o",
      usage: { prompt_tokens: 100, completion_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  def stub_openai_api_with_markdown_json
    json_content = {
      name: "Test Activity",
      schedule_type: "flexible",
      confidence_score: 75
    }

    response_body = {
      choices: [
        {
          message: {
            content: "```json\n#{json_content.to_json}\n```"
          }
        }
      ],
      model: "gpt-4o",
      usage: { prompt_tokens: 100, completion_tokens: 150 }
    }.to_json

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end
end
