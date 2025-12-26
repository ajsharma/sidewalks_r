# Controller for retrying failed AI activity suggestions
# :reek:DuplicateMethodCall
# :reek:InstanceVariableAssumption
module AiActivities
  # Handles retrying of failed AI suggestions
  class RetriesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_suggestion

    # POST /ai_activities/:ai_activity_id/retry
    # Retries a failed or completed suggestion to get a new AI response
    def create
      return render_retry_not_allowed unless can_retry_suggestion?

      input = @suggestion.text? ? @suggestion.input_text : @suggestion.source_url
      target_suggestion, suggestion_id = setup_retry_suggestion
      request_id = queue_retry_job(input, suggestion_id)

      render_retry_response(request_id, target_suggestion)
    rescue AiActivityService::RateLimitExceededError => e
      handle_rate_limit_error(e)
    end

    private

    def set_suggestion
      @suggestion = current_user.ai_suggestions.find(params[:ai_activity_id])
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.json { render json: { error: "Suggestion not found" }, status: :not_found }
        format.html { redirect_to ai_activities_path, alert: "Suggestion not found" }
      end
    end

    def can_retry_suggestion?
      @suggestion.failed? || (@suggestion.completed? && !@suggestion.accepted?)
    end

    def render_retry_not_allowed
      respond_to do |format|
        format.json { render json: { error: "Cannot retry accepted suggestions" }, status: :unprocessable_entity }
        format.html { redirect_to ai_activity_path(@suggestion), alert: "Cannot retry accepted suggestions" }
      end
    end

    def setup_retry_suggestion
      if @suggestion.failed?
        @suggestion.retry!
        [ @suggestion, @suggestion.id ]
      else
        new_suggestion = current_user.ai_suggestions.create!(
          input_type: @suggestion.input_type,
          input_text: @suggestion.input_text,
          source_url: @suggestion.source_url,
          status: "pending"
        )
        [ new_suggestion, nil ]
      end
    end

    def queue_retry_job(input, suggestion_id)
      request_id = SecureRandom.uuid
      AiSuggestionGeneratorJob.perform_later(
        user_id: current_user.id,
        input: input,
        request_id: request_id,
        suggestion_id: suggestion_id
      )
      request_id
    end

    def render_retry_response(request_id, target_suggestion)
      respond_to do |format|
        format.json { render_retry_json(request_id, target_suggestion) }
        format.turbo_stream { render_retry_turbo_stream(request_id) }
        format.html { redirect_to ai_activities_path, notice: "Generating new AI suggestion..." }
      end
    end

    def render_retry_json(request_id, target_suggestion)
      render json: {
        request_id: request_id,
        status: "processing",
        message: "AI is generating a new suggestion...",
        new_suggestion_id: target_suggestion.id
      }
    end

    def render_retry_turbo_stream(request_id)
      if @suggestion.failed?
        render turbo_stream: turbo_stream.replace(
          "suggestion_#{@suggestion.id}",
          partial: "ai_activities/suggestion_card",
          locals: { suggestion: @suggestion.reload }
        )
      else
        render turbo_stream: turbo_stream.prepend(
          "ai-suggestions-list",
          partial: "ai_activities/processing_placeholder",
          locals: { request_id: request_id }
        )
      end
    end

    def handle_rate_limit_error(error)
      respond_to do |format|
        format.json { render json: { error: error.message }, status: :too_many_requests }
        format.html { redirect_to ai_activity_path(@suggestion), alert: error.message }
      end
    end
  end
end
