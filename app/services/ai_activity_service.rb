# Orchestration service for generating AI-powered activity suggestions.
# Coordinates URL extraction, Claude API calls, rate limiting, and suggestion persistence.
class AiActivityService
  # Raised when user exceeds per-hour or per-day rate limits
  class RateLimitExceededError < StandardError; end

  RATE_LIMIT_PER_HOUR = 20
  RATE_LIMIT_PER_DAY = 100

  def initialize(user:, input:)
    @user = user
    @input = input.strip
    @input_type = detect_input_type
    @suggestion = nil
  end

  # Main entry point for generating suggestions
  # @return [AiActivitySuggestion] the created suggestion record
  def generate_suggestion
    check_rate_limits!

    # Create pending suggestion record
    @suggestion = create_pending_suggestion

    begin
      # Process based on input type
      result = case @input_type
      when :url
                 generate_from_url
      when :text
                 generate_from_text
      end

      # Mark as completed with the AI response
      @suggestion.mark_completed!(result)
      @suggestion
    rescue StandardError => e
      @suggestion&.mark_failed!(e)
      raise
    end
  end

  # Accepts a suggestion and creates an Activity
  # @param suggestion [AiActivitySuggestion] the suggestion to accept
  # @param user_edits [Hash] any edits made by the user
  # @return [Activity] the created activity
  def self.accept_suggestion(suggestion, user_edits: {})
    activity_params = build_activity_params(suggestion.suggested_data, user_edits)

    Activity.transaction do
      activity = suggestion.user.activities.create!(activity_params.merge(
        ai_generated: true,
        source_url: suggestion.source_url
      ))

      # Track user edits for learning
      track_user_edits(suggestion, user_edits) if user_edits.present?

      suggestion.accept!(activity)
      activity
    end
  end

  private

  def detect_input_type
    @input.match?(%r{\Ahttps?://}i) ? :url : :text
  end

  def check_rate_limits!
    hourly_count = @user.ai_suggestions
                        .where("created_at > ?", 1.hour.ago)
                        .count

    if hourly_count >= RATE_LIMIT_PER_HOUR
      raise RateLimitExceededError, "Rate limit exceeded: #{RATE_LIMIT_PER_HOUR} requests per hour"
    end

    daily_count = @user.ai_suggestions
                       .where("created_at > ?", 1.day.ago)
                       .count

    if daily_count >= RATE_LIMIT_PER_DAY
      raise RateLimitExceededError, "Rate limit exceeded: #{RATE_LIMIT_PER_DAY} requests per day"
    end
  end

  def create_pending_suggestion
    @user.ai_suggestions.create!(
      input_type: @input_type,
      input_text: @input_type == :text ? @input : nil,
      source_url: @input_type == :url ? @input : nil,
      status: "pending"
    )
  end

  def generate_from_text
    start_time = Time.current

    claude_service = ClaudeApiService.new
    ai_response = claude_service.extract_activity_from_text(@input)

    processing_time = ((Time.current - start_time) * 1000).to_i

    # Update suggestion with API metadata
    @suggestion.update!(
      model_used: ai_response["api_metadata"]["model"],
      processing_time_ms: processing_time,
      api_request: { input: @input },
      api_response: ai_response["api_metadata"]["usage"]
    )

    # Return structured data
    extract_suggestion_data(ai_response)
  end

  def generate_from_url
    start_time = Time.current

    # Step 1: Extract URL content
    url_extractor = UrlExtractorService.new(@input)
    url_data = url_extractor.extract

    # Update suggestion with extracted metadata
    @suggestion.update!(
      extracted_metadata: url_data[:structured_data]
    )

    # Step 2: Call AI to parse/enhance the data
    claude_service = ClaudeApiService.new
    ai_response = if url_data[:needs_ai_parsing]
                    claude_service.extract_activity_from_url(
                      url: @input,
                      html_content: url_data[:html_content],
                      structured_data: url_data[:structured_data]
                    )
    else
                    # Use structured data directly, but still run through AI for categorization
                    claude_service.extract_activity_from_url(
                      url: @input,
                      html_content: nil,
                      structured_data: url_data[:structured_data]
                    )
    end

    processing_time = ((Time.current - start_time) * 1000).to_i

    # Update suggestion with API metadata
    @suggestion.update!(
      model_used: ai_response["api_metadata"]["model"],
      processing_time_ms: processing_time,
      api_request: { url: @input, needs_ai_parsing: url_data[:needs_ai_parsing] },
      api_response: ai_response["api_metadata"]["usage"]
    )

    # Merge URL metadata with AI response
    suggestion_data = extract_suggestion_data(ai_response)
    suggestion_data[:image_url] = url_data.dig(:structured_data, :image_url) if url_data.dig(:structured_data, :image_url)
    suggestion_data[:organizer] = url_data.dig(:structured_data, :organizer) if url_data.dig(:structured_data, :organizer)
    suggestion_data[:price] = url_data.dig(:structured_data, :price) if url_data.dig(:structured_data, :price)

    suggestion_data
  end

  def extract_suggestion_data(ai_response)
    {
      name: ai_response["name"],
      description: ai_response["description"],
      schedule_type: ai_response["schedule_type"],
      suggested_months: ai_response["suggested_months"] || [],
      suggested_days_of_week: ai_response["suggested_days_of_week"] || [],
      suggested_time_of_day: ai_response["suggested_time_of_day"],
      category_tags: ai_response["category_tags"] || [],
      duration_estimate: ai_response["duration_estimate"],
      confidence_score: ai_response["confidence_score"],
      reasoning: ai_response["reasoning"]
    }
  end

  def self.build_activity_params(suggested_data, user_edits)
    # Start with AI suggested data
    params = {
      name: suggested_data[:name] || suggested_data["name"],
      description: suggested_data[:description] || suggested_data["description"],
      schedule_type: suggested_data[:schedule_type] || suggested_data["schedule_type"] || "flexible",
      suggested_months: suggested_data[:suggested_months] || suggested_data["suggested_months"] || [],
      suggested_days_of_week: suggested_data[:suggested_days_of_week] || suggested_data["suggested_days_of_week"] || [],
      suggested_time_of_day: suggested_data[:suggested_time_of_day] || suggested_data["suggested_time_of_day"],
      category_tags: suggested_data[:category_tags] || suggested_data["category_tags"] || []
    }

    # Apply user edits
    params.merge!(user_edits.symbolize_keys) if user_edits.present?

    params
  end

  def self.track_user_edits(suggestion, user_edits)
    # Store what the user changed for future learning
    edits_summary = {}

    user_edits.each do |field, new_value|
      original_value = suggestion.suggested_data[field.to_s]
      if original_value != new_value
        edits_summary[field] = {
          original: original_value,
          edited: new_value
        }
      end
    end

    suggestion.update!(user_edits: edits_summary) if edits_summary.present?
  end
end
