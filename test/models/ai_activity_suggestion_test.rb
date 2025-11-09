require "test_helper"

class AiActivitySuggestionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @suggestion = ai_activity_suggestions(:text_completed)
  end

  # Associations
  test "belongs to user" do
    assert_instance_of User, @suggestion.user
    assert_equal @user, @suggestion.user
  end

  test "can have a final_activity" do
    activity = activities(:one)
    @suggestion.update!(final_activity: activity)
    assert_equal activity, @suggestion.final_activity
  end

  # Enums
  test "input_type enum works" do
    suggestion = AiActivitySuggestion.new(user: @user, input_text: "test")
    assert_equal "text", suggestion.input_type

    suggestion.input_type = :url
    assert_equal "url", suggestion.input_type
  end

  test "status enum works" do
    suggestion = AiActivitySuggestion.new(user: @user, input_text: "test")
    assert_equal "pending", suggestion.status

    suggestion.status = :processing
    assert_equal "processing", suggestion.status

    suggestion.status = :completed
    assert_equal "completed", suggestion.status

    suggestion.status = :failed
    assert_equal "failed", suggestion.status
  end

  # Validations
  test "requires input_type" do
    suggestion = AiActivitySuggestion.new(user: @user)
    suggestion.input_type = nil
    assert_not suggestion.valid?
    assert_includes suggestion.errors[:input_type], "can't be blank"
  end

  test "requires input_text for text type" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :text)
    assert_not suggestion.valid?
    assert_includes suggestion.errors[:input_text], "can't be blank"
  end

  test "requires source_url for url type" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :url)
    assert_not suggestion.valid?
    assert_includes suggestion.errors[:source_url], "can't be blank"
  end

  test "validates url format" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :url, source_url: "not-a-url")
    assert_not suggestion.valid?
    assert_includes suggestion.errors[:source_url], "is invalid"
  end

  test "accepts valid http url" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :url, source_url: "http://example.com")
    assert suggestion.valid?
  end

  test "accepts valid https url" do
    suggestion = AiActivitySuggestion.new(user: @user, input_type: :url, source_url: "https://example.com")
    assert suggestion.valid?
  end

  test "validates confidence_score range" do
    suggestion = @suggestion

    suggestion.confidence_score = -1
    assert_not suggestion.valid?

    suggestion.confidence_score = 101
    assert_not suggestion.valid?

    suggestion.confidence_score = 50
    assert suggestion.valid?
  end

  # Scopes
  test "recent scope orders by created_at desc" do
    suggestions = AiActivitySuggestion.recent
    assert_equal suggestions.to_sql, AiActivitySuggestion.order(created_at: :desc).to_sql
  end

  test "accepted scope returns only accepted suggestions" do
    accepted = AiActivitySuggestion.accepted
    assert_includes accepted, ai_activity_suggestions(:accepted_suggestion)
    assert_not_includes accepted, ai_activity_suggestions(:text_completed)
  end

  test "rejected scope returns unaccepted completed suggestions" do
    rejected = AiActivitySuggestion.rejected
    # Should include completed but not accepted
    assert_includes rejected, ai_activity_suggestions(:text_completed)
    assert_not_includes rejected, ai_activity_suggestions(:accepted_suggestion)
    assert_not_includes rejected, ai_activity_suggestions(:text_pending)
  end

  test "for_user scope filters by user" do
    user_suggestions = AiActivitySuggestion.for_user(@user)
    user_suggestions.each do |suggestion|
      assert_equal @user, suggestion.user
    end
  end

  # Instance methods
  test "accept! marks suggestion as accepted and sets activity" do
    suggestion = ai_activity_suggestions(:text_completed)
    activity = activities(:one)

    assert_not suggestion.accepted

    suggestion.accept!(activity)

    assert suggestion.accepted
    assert_not_nil suggestion.accepted_at
    assert_equal activity, suggestion.final_activity
    assert_equal "completed", suggestion.status
  end

  test "reject! marks suggestion as rejected" do
    suggestion = ai_activity_suggestions(:text_completed)

    suggestion.reject!

    assert_not suggestion.accepted
    assert_equal "completed", suggestion.status
  end

  test "mark_processing! updates status" do
    suggestion = ai_activity_suggestions(:text_pending)

    suggestion.mark_processing!

    assert_equal "processing", suggestion.status
  end

  test "mark_completed! updates status and data" do
    suggestion = ai_activity_suggestions(:text_pending)
    data = { "name" => "Test Activity", "confidence_score" => 85 }

    suggestion.mark_completed!(data)

    assert_equal "completed", suggestion.status
    assert_equal data, suggestion.suggested_data
    assert_equal 85, suggestion.confidence_score
  end

  test "mark_failed! updates status and error message" do
    suggestion = ai_activity_suggestions(:text_pending)
    error = StandardError.new("Something went wrong")

    suggestion.mark_failed!(error)

    assert_equal "failed", suggestion.status
    assert_equal "Something went wrong", suggestion.error_message
  end

  test "processing_cost calculates based on API usage" do
    suggestion = ai_activity_suggestions(:text_completed)
    # Input: 150 tokens, Output: 200 tokens
    # Cost: (150/1M * $3) + (200/1M * $15) = 0.00045 + 0.003 = 0.00345

    expected_cost = (150 / 1_000_000.0 * 3.0) + (200 / 1_000_000.0 * 15.0)
    assert_in_delta expected_cost, suggestion.processing_cost, 0.00001
  end

  test "processing_cost returns 0 when no api_response" do
    suggestion = ai_activity_suggestions(:text_pending)
    assert_equal 0, suggestion.processing_cost
  end

  test "suggested_activity_name returns name from suggested_data" do
    suggestion = ai_activity_suggestions(:text_completed)
    assert_equal "Farmers Market Visit", suggestion.suggested_activity_name
  end

  test "suggested_activity_name returns default when no name" do
    suggestion = ai_activity_suggestions(:text_pending)
    assert_equal "Untitled Activity", suggestion.suggested_activity_name
  end

  test "suggested_description returns description from suggested_data" do
    suggestion = ai_activity_suggestions(:text_completed)
    assert_equal "Visit local farmers market", suggestion.suggested_description
  end

  test "confidence_label returns appropriate label" do
    suggestion = @suggestion

    suggestion.confidence_score = 25
    assert_equal "Low confidence", suggestion.confidence_label

    suggestion.confidence_score = 50
    assert_equal "Moderate confidence", suggestion.confidence_label

    suggestion.confidence_score = 75
    assert_equal "Good confidence", suggestion.confidence_label

    suggestion.confidence_score = 90
    assert_equal "High confidence", suggestion.confidence_label

    suggestion.confidence_score = nil
    assert_equal "Unknown", suggestion.confidence_label
  end

  # Callbacks
  test "normalizes input_text on validation" do
    suggestion = AiActivitySuggestion.new(
      user: @user,
      input_type: :text,
      input_text: "  test activity  "
    )
    suggestion.validate
    assert_equal "test activity", suggestion.input_text
  end

  test "normalizes source_url on validation" do
    suggestion = AiActivitySuggestion.new(
      user: @user,
      input_type: :url,
      source_url: "  https://example.com  "
    )
    suggestion.validate
    assert_equal "https://example.com", suggestion.source_url
  end
end
