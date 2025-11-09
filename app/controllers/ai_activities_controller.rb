class AiActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :check_ai_feature_enabled
  before_action :set_suggestion, only: [:show, :accept, :reject, :destroy]

  # GET /ai_activities
  def index
    @suggestions = current_user.ai_suggestions
                              .includes(:final_activity)
                              .recent
                              .limit(50)
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
      return render json: { error: 'Input cannot be blank' }, status: :unprocessable_entity
    end

    # Generate unique request ID for tracking
    request_id = SecureRandom.uuid

    # Queue the background job
    AiSuggestionGeneratorJob.perform_later(
      current_user.id,
      input,
      request_id: request_id
    )

    respond_to do |format|
      format.json do
        render json: {
          request_id: request_id,
          status: 'processing',
          message: 'AI is analyzing your input...'
        }
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          'ai-suggestions-list',
          partial: 'ai_activities/processing_placeholder',
          locals: { request_id: request_id }
        )
      end
      format.html do
        redirect_to ai_activities_path, notice: 'AI is processing your suggestion...'
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
    # Display a single suggestion
  end

  # POST /ai_activities/:id/accept
  # Accepts the suggestion and creates an Activity
  def accept
    user_edits = params.permit(:name, :description, :schedule_type, suggested_months: [], suggested_days_of_week: [], category_tags: [])
                      .to_h
                      .compact
                      .reject { |_, v| v.blank? }

    @activity = AiActivityService.accept_suggestion(@suggestion, user_edits: user_edits)

    respond_to do |format|
      format.json do
        render json: {
          activity: @activity,
          message: 'Activity created successfully'
        }, status: :created
      end
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("suggestion_#{@suggestion.id}"),
          turbo_stream.prepend('activities-list', partial: 'activities/activity', locals: { activity: @activity })
        ]
      end
      format.html do
        redirect_to activity_path(@activity), notice: 'Activity created from AI suggestion!'
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
      format.json { render json: { message: 'Suggestion rejected' } }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("suggestion_#{@suggestion.id}")
      end
      format.html do
        redirect_to ai_activities_path, notice: 'Suggestion dismissed'
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
        redirect_to ai_activities_path, notice: 'Suggestion deleted'
      end
    end
  end

  private

  def set_suggestion
    @suggestion = current_user.ai_suggestions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { error: 'Suggestion not found' }, status: :not_found }
      format.html { redirect_to ai_activities_path, alert: 'Suggestion not found' }
    end
  end

  def check_ai_feature_enabled
    unless ai_feature_enabled?
      respond_to do |format|
        format.json { render json: { error: 'AI feature not enabled' }, status: :forbidden }
        format.html { redirect_to root_path, alert: 'AI suggestions are not currently available' }
      end
    end
  end

  def ai_feature_enabled?
    # Check if AI feature is enabled via ENV var or feature flag
    ENV.fetch('AI_FEATURE_ENABLED', 'false') == 'true'
  end
end
