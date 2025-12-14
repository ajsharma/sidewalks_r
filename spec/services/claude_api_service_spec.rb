require "rails_helper"

RSpec.describe ClaudeApiService, type: :service do
  before do
    # AI config is loaded from config/ai.yml test environment
    # Set provider to anthropic for these tests
    @original_provider = AiConfig.instance.provider
    AiConfig.instance.provider = "anthropic"
    @service = described_class.new
  end

  after do
    AiConfig.instance.provider = @original_provider
  end

  it "raises error when ANTHROPIC_API_KEY is not set" do
    # Temporarily override config to test error handling
    original_key = AiConfig.instance.anthropic_api_key
    AiConfig.instance.anthropic_api_key = nil

    expect {
      described_class.new
    }.to raise_error(ClaudeApiService::ApiError, "ANTHROPIC_API_KEY not configured")
  ensure
    AiConfig.instance.anthropic_api_key = original_key
  end

  it "extract_activity_from_text returns structured data" do
    stub_claude_api_success

    result = @service.extract_activity_from_text("Go hiking this weekend")

    expect(result["name"]).to eq "Weekend Hiking"
    expect(result["schedule_type"]).to eq "flexible"
    expect(result["confidence_score"]).to eq 85
    expect(result["suggested_months"]).to eq [ 6, 7 ]
    expect(result["api_metadata"]).not_to be_nil
  end

  it "extract_activity_from_text handles API errors" do
    stub_claude_api_error(500)

    expect {
      @service.extract_activity_from_text("test input")
    }.to raise_error(ClaudeApiService::ApiError, /API server error/)
  end

  it "extract_activity_from_text handles rate limit errors" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 429, body: { error: { message: "API rate limit exceeded" } }.to_json)

    expect {
      @service.extract_activity_from_text("test input")
    }.to raise_error(ClaudeApiService::RateLimitError, /rate limit/)
  end

  it "extract_activity_from_text handles timeout" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_timeout

    expect {
      @service.extract_activity_from_text("test input")
    }.to raise_error(ClaudeApiService::ApiError, /timed out|execution expired/)
  end

  it "extract_activity_from_url returns structured data with metadata" do
    stub_claude_api_success

    result = @service.extract_activity_from_url(
      url: "https://example.com/event",
      structured_data: { name: "Concert", description: "Music event" }
    )

    expect(result["name"]).to eq "Weekend Hiking"
    expect(result["api_metadata"]).not_to be_nil
  end

  it "validates response structure requires name" do
    stub_claude_api_response_without_required_fields

    expect {
      @service.extract_activity_from_text("test input")
    }.to raise_error(ClaudeApiService::InvalidResponseError, /Missing required fields/)
  end

  it "validates schedule_type is valid" do
    stub_claude_api_with_invalid_schedule_type

    expect {
      @service.extract_activity_from_text("test input")
    }.to raise_error(ClaudeApiService::InvalidResponseError, /Invalid schedule_type/)
  end

  it "validates confidence_score is in range" do
    stub_claude_api_with_invalid_confidence

    expect {
      @service.extract_activity_from_text("test input")
    }.to raise_error(ClaudeApiService::InvalidResponseError, /Invalid confidence_score/)
  end

  it "parses JSON from markdown code blocks" do
    stub_claude_api_with_markdown_json

    result = @service.extract_activity_from_text("test input")

    expect(result["name"]).to eq "Test Activity"
    expect(result["confidence_score"]).to eq 75
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
