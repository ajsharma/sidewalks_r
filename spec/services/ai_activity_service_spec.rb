require "rails_helper"

RSpec.describe AiActivityService, type: :service do
  before do
    @user = users(:one)
    # Use Anthropic provider for these tests since they stub Claude API
    @original_provider = AiConfig.instance.provider
    AiConfig.instance.provider = "anthropic"
  end

  after do
    AiConfig.instance.provider = @original_provider
  end

  it "detects text input type" do
    service = described_class.new(user: @user, input: "Go for a run")
    expect(service.instance_variable_get(:@input_type)).to eq :text
  end

  it "detects url input type" do
    service = described_class.new(user: @user, input: "https://example.com/event")
    expect(service.instance_variable_get(:@input_type)).to eq :url
  end

  it "checks rate limits before processing" do
    # Temporarily set lower rate limits for testing
    original_hourly = AiConfig.instance.rate_limit_per_hour
    AiConfig.instance.rate_limit_per_hour = 20

    # Create 20 suggestions in the last hour
    20.times do
      @user.ai_suggestions.create!(
        input_type: :text,
        input_text: "test",
        created_at: 30.minutes.ago
      )
    end

    service = described_class.new(user: @user, input: "test")

    expect {
      service.generate_suggestion
    }.to raise_error(AiActivityService::RateLimitExceededError, /20 requests per hour/)
  ensure
    AiConfig.instance.rate_limit_per_hour = original_hourly
  end

  it "checks daily rate limits" do
    # Temporarily set lower rate limits for testing
    original_daily = AiConfig.instance.rate_limit_per_day
    AiConfig.instance.rate_limit_per_day = 100

    # Create 100 suggestions in the last day
    100.times do |i|
      @user.ai_suggestions.create!(
        input_type: :text,
        input_text: "test #{i}",
        created_at: (i * 10).minutes.ago
      )
    end

    service = described_class.new(user: @user, input: "test")

    expect {
      service.generate_suggestion
    }.to raise_error(AiActivityService::RateLimitExceededError, /100 requests per day/)
  ensure
    AiConfig.instance.rate_limit_per_day = original_daily
  end

  it "generate_suggestion creates pending suggestion for text" do
    stub_successful_claude_api

    service = described_class.new(user: @user, input: "Weekly team meeting")

    expect {
      suggestion = service.generate_suggestion

      expect(suggestion.input_type).to eq "text"
      expect(suggestion.input_text).to eq "Weekly team meeting"
      expect(suggestion.status).to eq "completed"
      expect(suggestion.suggested_data).not_to be_nil
    }.to change { @user.ai_suggestions.count }.by(1)
  end

  it "generate_suggestion marks failed on error" do
    stub_failing_claude_api

    service = described_class.new(user: @user, input: "test")

    expect {
      service.generate_suggestion
    }.to raise_error(ClaudeApiService::ApiError)

    suggestion = @user.ai_suggestions.last
    expect(suggestion.status).to eq "failed"
    expect(suggestion.error_message).not_to be_nil
  end

  it "accept_suggestion creates activity from suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    expect {
      activity = described_class.accept_suggestion(suggestion)

      expect(activity.persisted?).to be true
      expect(activity.ai_generated?).to be true
      expect(activity.name).to eq "Farmers Market Visit"
      expect(activity.user).to eq suggestion.user
    }.to change(Activity, :count).by(1)
  end

  it "accept_suggestion with user edits applies changes" do
    suggestion = ai_activity_suggestions(:text_completed)
    user_edits = {
      name: "My Custom Market Visit",
      description: "Custom description"
    }

    activity = described_class.accept_suggestion(suggestion, user_edits: user_edits)

    expect(activity.name).to eq "My Custom Market Visit"
    expect(activity.description).to eq "Custom description"
  end

  it "accept_suggestion tracks user edits" do
    suggestion = ai_activity_suggestions(:text_completed)
    user_edits = {
      name: "Edited Name"
    }

    described_class.accept_suggestion(suggestion, user_edits: user_edits)

    suggestion.reload
    expect(suggestion.user_edits).not_to be_empty
    expect(suggestion.user_edits["name"]["original"]).to eq "Farmers Market Visit"
    expect(suggestion.user_edits["name"]["edited"]).to eq "Edited Name"
  end

  it "accept_suggestion marks suggestion as accepted" do
    suggestion = ai_activity_suggestions(:text_completed)

    activity = described_class.accept_suggestion(suggestion)

    suggestion.reload
    expect(suggestion.accepted).to be true
    expect(suggestion.accepted_at).not_to be_nil
    expect(suggestion.final_activity).to eq activity
  end

  it "build_activity_params extracts data correctly" do
    suggested_data = {
      "name" => "Test Activity",
      "description" => "Test description",
      "schedule_type" => "flexible",
      "suggested_months" => [ 6, 7, 8 ],
      "suggested_days_of_week" => [ 0, 6 ],
      "suggested_time_of_day" => "morning",
      "category_tags" => [ "outdoor" ]
    }

    params = described_class.build_activity_params(suggested_data, {})

    expect(params[:name]).to eq "Test Activity"
    expect(params[:description]).to eq "Test description"
    expect(params[:schedule_type]).to eq "flexible"
    expect(params[:suggested_months]).to eq [ 6, 7, 8 ]
  end

  it "build_activity_params merges user edits" do
    suggested_data = { "name" => "Original", "description" => "Original desc" }
    user_edits = { "name" => "Edited" }

    params = described_class.build_activity_params(suggested_data, user_edits)

    expect(params[:name]).to eq "Edited"
    expect(params[:description]).to eq "Original desc"
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
