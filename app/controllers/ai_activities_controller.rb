# Controller for managing AI-generated activity suggestions.
# Handles suggestion generation, viewing, accepting, rejecting, and deletion.
class AiActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :check_ai_feature_enabled
  before_action :set_suggestion, only: [ :show, :accept, :reject, :destroy, :retry ]

  # GET /ai_activities
  def index
    @suggestions = current_user.ai_suggestions
                              .recent
                              .limit(50)

    respond_to do |format|
      format.html
      format.json { render json: @suggestions }
    end
  end

  # GET /ai_activities/new
  def new
    # Display the AI suggestion form
  end

  # POST /ai_activities/generate
  # Initiates AI suggestion generation (async)
  def generate
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

  # GET /ai_activities/:id
  def show
    respond_to do |format|
      format.html # Display a single suggestion
      format.json { render json: @suggestion }
    end
  end

  # POST /ai_activities/:id/accept
  # Accepts the suggestion and creates an Activity
  def accept
    user_edits = params.permit(
      :name, :description, :schedule_type, :duration_minutes,
      :recurrence_start_date, :recurrence_end_date,
      :occurrence_time_start, :occurrence_time_end,
      suggested_months: [], suggested_days_of_week: [], category_tags: [],
      recurrence_rule: {}
    ).to_h
     .compact
     .reject { |_, v| v.blank? }

    @activity = AiActivityService.accept_suggestion(@suggestion, user_edits: user_edits)

    respond_to do |format|
      format.json do
        render json: {
          activity: @activity,
          message: "Activity created successfully"
        }, status: :created
      end
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("suggestion_#{@suggestion.id}"),
          turbo_stream.prepend("activities-list", partial: "activities/activity", locals: { activity: @activity })
        ]
      end
      format.html do
        redirect_to activity_path(@activity), notice: "Activity created from AI suggestion!"
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to ai_activity_path(@suggestion), alert: "Failed to create activity: #{e.message}" }
    end
  end

  # POST /ai_activities/:id/reject
  # Rejects the suggestion
  def reject
    @suggestion.reject!

    respond_to do |format|
      format.json { render json: { message: "Suggestion rejected" } }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("suggestion_#{@suggestion.id}")
      end
      format.html do
        redirect_to ai_activities_path, notice: "Suggestion dismissed"
      end
    end
  end

  # DELETE /ai_activities/:id
  # Deletes the suggestion
  def destroy
    @suggestion.destroy

    respond_to do |format|
      format.json { head :no_content }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("suggestion_#{@suggestion.id}")
      end
      format.html do
        redirect_to ai_activities_path, notice: "Suggestion deleted"
      end
    end
  end

  # POST /ai_activities/:id/retry
  # Retries a failed or completed suggestion to get a new AI response
  def retry
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
    @suggestion = current_user.ai_suggestions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { error: "Suggestion not found" }, status: :not_found }
      format.html { redirect_to ai_activities_path, alert: "Suggestion not found" }
    end
  end

  def check_ai_feature_enabled
    unless ai_feature_enabled?
      respond_to do |format|
        format.json { render json: { error: "AI feature not enabled" }, status: :forbidden }
        format.html { redirect_to root_path, alert: "AI suggestions are not currently available" }
      end
    end
  end

  def ai_feature_enabled?
    AiConfig.instance.feature_enabled?
  end

  # Retry helper methods
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
