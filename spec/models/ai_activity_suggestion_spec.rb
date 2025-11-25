require "rails_helper"

RSpec.describe AiActivitySuggestion, type: :model do
  before do
    @user = users(:one)
    @suggestion = ai_activity_suggestions(:text_completed)
  end

  # Associations
  it "belongs to user" do
    expect(@suggestion.user).to be_an_instance_of(User)
    expect(@suggestion.user).to eq(@user)
  end

  it "can have a final_activity" do
    activity = activities(:one)
    @suggestion.update!(final_activity: activity)
    expect(@suggestion.final_activity).to eq(activity)
  end

  # Enums
  it "input_type enum works" do
    suggestion = AiActivitySuggestion.new(user: @user, input_text: "test")
    expect(suggestion.input_type).to eq("text")

    suggestion.input_type = :url
    expect(suggestion.input_type).to eq("url")
  end

  it "status enum works" do
    suggestion = AiActivitySuggestion.new(user: @user, input_text: "test")
    expect(suggestion.status).to eq("pending")

    suggestion.status = :processing
    expect(suggestion.status).to eq("processing")

    suggestion.status = :completed
    expect(suggestion.status).to eq("completed")

    suggestion.status = :failed
    expect(suggestion.status).to eq("failed")
  end

  # Validations
  it "requires input_type" do
    suggestion = AiActivitySuggestion.new(user: @user)
    suggestion.input_type = nil
    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:input_type]).to include("can't be blank")
  end

  it "requires input_text for text type" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :text)
    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:input_text]).to include("can't be blank")
  end

  it "requires source_url for url type" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :url)
    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:source_url]).to include("can't be blank")
  end

  it "validates url format" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :url, source_url: "not-a-url")
    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:source_url]).to include("is invalid")
  end

  it "accepts valid http url" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :url, source_url: "http://example.com")
    expect(suggestion).to be_valid
  end

  it "accepts valid https url" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :url, source_url: "https://example.com")
    expect(suggestion).to be_valid
  end

  it "validates confidence_score range" do
    suggestion = @suggestion

    suggestion.confidence_score = -1
    expect(suggestion).not_to be_valid

    suggestion.confidence_score = 101
    expect(suggestion).not_to be_valid

    suggestion.confidence_score = 50
    expect(suggestion).to be_valid
  end

  # Scopes
  it "recent scope orders by created_at desc" do
    suggestions = AiActivitySuggestion.recent
    expect(suggestions.to_sql).to eq(AiActivitySuggestion.order(created_at: :desc).to_sql)
  end

  it "accepted scope returns only accepted suggestions" do
    accepted = AiActivitySuggestion.accepted
    expect(accepted).to include(ai_activity_suggestions(:accepted_suggestion))
    expect(accepted).not_to include(ai_activity_suggestions(:text_completed))
  end

  it "rejected scope returns unaccepted completed suggestions" do
    rejected = AiActivitySuggestion.rejected
    # Should include completed but not accepted
    expect(rejected).to include(ai_activity_suggestions(:text_completed))
    expect(rejected).not_to include(ai_activity_suggestions(:accepted_suggestion))
    expect(rejected).not_to include(ai_activity_suggestions(:text_pending))
  end

  it "for_user scope filters by user" do
    user_suggestions = AiActivitySuggestion.for_user(@user)
    user_suggestions.each do |suggestion|
      expect(suggestion.user).to eq(@user)
    end
  end

  # Instance methods
  it "accept! marks suggestion as accepted and sets activity" do
    suggestion = ai_activity_suggestions(:text_completed)
    activity = activities(:one)

    expect(suggestion.accepted).to be_falsey

    suggestion.accept!(activity)

    expect(suggestion.accepted).to be_truthy
    expect(suggestion.accepted_at).not_to be_nil
    expect(suggestion.final_activity).to eq(activity)
    expect(suggestion.status).to eq("completed")
  end

  it "reject! marks suggestion as rejected" do
    suggestion = ai_activity_suggestions(:text_completed)

    suggestion.reject!

    expect(suggestion.accepted).to be_falsey
    expect(suggestion.status).to eq("completed")
  end

  it "mark_processing! updates status" do
    suggestion = ai_activity_suggestions(:text_pending)

    suggestion.mark_processing!

    expect(suggestion.status).to eq("processing")
  end

  it "mark_completed! updates status and data" do
    suggestion = ai_activity_suggestions(:text_pending)
    data = { "name" => "Test Activity", "confidence_score" => 85 }

    suggestion.mark_completed!(data)

    expect(suggestion.status).to eq("completed")
    expect(suggestion.suggested_data).to eq(data)
    expect(suggestion.confidence_score).to eq(85)
  end

  it "mark_failed! updates status and error message" do
    suggestion = ai_activity_suggestions(:text_pending)
    error = StandardError.new("Something went wrong")

    suggestion.mark_failed!(error)

    expect(suggestion.status).to eq("failed")
    expect(suggestion.error_message).to eq("Something went wrong")
  end

  it "processing_cost calculates based on API usage" do
    suggestion = ai_activity_suggestions(:text_completed)
    # Input: 150 tokens, Output: 200 tokens
    # Cost: (150/1M * $3) + (200/1M * $15) = 0.00045 + 0.003 = 0.00345

    expected_cost = (150 / 1_000_000.0 * 3.0) + (200 / 1_000_000.0 * 15.0)
    expect(suggestion.processing_cost).to be_within(0.00001).of(expected_cost)
  end

  it "processing_cost returns 0 when no api_response" do
    suggestion = ai_activity_suggestions(:text_pending)
    expect(suggestion.processing_cost).to eq(0)
  end

  it "suggested_activity_name returns name from suggested_data" do
    suggestion = ai_activity_suggestions(:text_completed)
    expect(suggestion.suggested_activity_name).to eq("Farmers Market Visit")
  end

  it "suggested_activity_name returns default when no name" do
    suggestion = ai_activity_suggestions(:text_pending)
    expect(suggestion.suggested_activity_name).to eq("Untitled Activity")
  end

  it "suggested_description returns description from suggested_data" do
    suggestion = ai_activity_suggestions(:text_completed)
    expect(suggestion.suggested_description).to eq("Visit local farmers market")
  end

  it "confidence_label returns appropriate label" do
    suggestion = @suggestion

    suggestion.confidence_score = 25
    expect(suggestion.confidence_label).to eq("Low confidence")

    suggestion.confidence_score = 50
    expect(suggestion.confidence_label).to eq("Moderate confidence")

    suggestion.confidence_score = 75
    expect(suggestion.confidence_label).to eq("Good confidence")

    suggestion.confidence_score = 90
    expect(suggestion.confidence_label).to eq("High confidence")

    suggestion.confidence_score = nil
    expect(suggestion.confidence_label).to eq("Unknown")
  end

  # Callbacks
  it "normalizes input_text on validation" do
    suggestion = AiActivitySuggestion.new(
      user: @user,
      input_type: :text,
      input_text: "  test activity  "
    )
    suggestion.validate
    expect(suggestion.input_text).to eq("test activity")
  end

  it "normalizes source_url on validation" do
    suggestion = AiActivitySuggestion.new(
      user: @user,
      input_type: :url,
      source_url: "  https://example.com  "
    )
    suggestion.validate
    expect(suggestion.source_url).to eq("https://example.com")
  end
end
