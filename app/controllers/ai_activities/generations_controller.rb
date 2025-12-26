# Controller for generating new AI activity suggestions
# :reek:DuplicateMethodCall
module AiActivities
  # Handles creation of AI activity suggestions
  class GenerationsController < ApplicationController
    before_action :authenticate_user!
    before_action :check_ai_feature_enabled

    # POST /ai_activities/generations
    # Initiates AI suggestion generation (async)
    def create
      input = params[:input]&.strip

      if input.blank?
        return render json: { error: "Input cannot be blank" }, status: :unprocessable_entity
      end

      # Generate unique request ID for tracking
      request_id = SecureRandom.uuid

      # Queue the background job
      AiSuggestionGeneratorJob.perform_later(
        user_id: current_user.id,
        input: input,
        request_id: request_id
      )

      respond_to do |format|
        format.json do
          render json: {
            request_id: request_id,
            status: "processing",
            message: "AI is analyzing your input..."
          }
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            "ai-suggestions-list",
            partial: "ai_activities/processing_placeholder",
            locals: { request_id: request_id }
          )
        end
        format.html do
          redirect_to ai_activities_path, notice: "AI is processing your suggestion..."
        end
      end
    rescue AiActivityService::RateLimitExceededError => e
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :too_many_requests }
        format.html { redirect_to ai_activities_path, alert: e.message }
      end
    end

    private

    def check_ai_feature_enabled
      return if ai_feature_enabled?

      respond_to do |format|
        format.json { render json: { error: "AI feature not enabled" }, status: :forbidden }
        format.html { redirect_to root_path, alert: "AI suggestions are not currently available" }
      end
    end

    def ai_feature_enabled?
      AiConfig.instance.feature_enabled?
    end
  end
end
