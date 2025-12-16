require "rails_helper"

RSpec.describe AiSuggestionGeneratorJob, type: :job do
  before do
    @user = users(:one)
    # Use Anthropic provider for these tests since they stub Claude API
    @original_provider = AiConfig.instance.provider
    AiConfig.instance.provider = "anthropic"
  end

  after do
    AiConfig.instance.provider = @original_provider
  end

  it "performs job and generates suggestion" do
    stub_successful_api

    expect {
      described_class.perform_now(
        user_id: @user.id,
        input: "Go hiking",
        request_id: "test-123"
      )
    }.to change { @user.ai_suggestions.count }.by(1)

    suggestion = @user.ai_suggestions.last
    expect(suggestion.status).to eq "completed"
  end

  it "handles API errors by marking suggestion as failed" do
    stub_failing_api

    # API errors should create a failed suggestion before re-raising
    begin
      described_class.perform_now(
        user_id: @user.id,
        input: "test input",
        request_id: "test-123"
      )
    rescue => e
      # Expected to raise for retry mechanism
    end

    # A failed suggestion should still be created
    failed_suggestion = @user.ai_suggestions.last
    expect(failed_suggestion.status).to eq "failed"
    expect(failed_suggestion.error_message).not_to be_nil
    expect(failed_suggestion.error_message).to match(/API|Failed to fetch URL/)
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
