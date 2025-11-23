# Background job for generating AI activity suggestions.
# Calls AI services asynchronously and broadcasts results via Turbo Streams.
class AiSuggestionGeneratorJob < ApplicationJob
  queue_as :default

  retry_on ClaudeApiService::ApiError, wait: :exponentially_longer, attempts: 3
  retry_on UrlExtractorService::FetchError, wait: 30.seconds, attempts: 2

  discard_on AiActivityService::RateLimitExceededError
  discard_on UrlExtractorService::InvalidUrlError
  discard_on ActiveRecord::RecordNotFound

  # Generate AI activity suggestion
  # @param params [Hash] job parameters
  # @option params [Integer] :user_id the user ID
  # @option params [String] :input the user's input (text or URL)
  # @option params [String] :request_id optional request ID for tracking
  # @option params [Integer] :suggestion_id optional existing suggestion ID for retries
  def perform(params)
    user_id = params[:user_id]
    input = params[:input]
    request_id = params[:request_id]
    suggestion_id = params[:suggestion_id]

    user = User.find(user_id)

    Rails.logger.info("AI suggestion job started: user=#{user_id}, request_id=#{request_id}, suggestion_id=#{suggestion_id}")

    service = AiActivityService.new(user: user, input: input, suggestion_id: suggestion_id)
    suggestion = service.generate_suggestion

    Rails.logger.info("AI suggestion completed: suggestion_id=#{suggestion.id}, request_id=#{request_id}")

    # Broadcast to user's Turbo Stream channel for real-time updates
    broadcast_suggestion_ready(user, suggestion)

  rescue StandardError => e
    Rails.logger.error("AI suggestion job failed: user=#{user_id}, error=#{e.message}, request_id=#{request_id}")
    broadcast_suggestion_error(user, e.message) if user
    raise
  end

  private

  def broadcast_suggestion_ready(user, suggestion)
    Turbo::StreamsChannel.broadcast_prepend_to(
      "ai_suggestions_#{user.id}",
      target: "ai-suggestions-list",
      partial: "ai_activities/suggestion_card",
      locals: { suggestion: suggestion }
    )
  end

  def broadcast_suggestion_error(user, error_message)
    Turbo::StreamsChannel.broadcast_append_to(
      "ai_suggestions_#{user.id}",
      target: "ai-suggestions-errors",
      partial: "ai_activities/error_message",
      locals: { error: error_message }
    )
  end
end
