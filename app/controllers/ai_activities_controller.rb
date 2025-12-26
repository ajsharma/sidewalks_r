# Controller for managing AI-generated activity suggestions.
# Handles viewing and deletion of suggestions.
# Generation, acceptance, rejection, and retry actions are handled by nested controllers.
class AiActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :check_ai_feature_enabled
  before_action :set_suggestion, only: [ :show, :destroy ]

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

  # GET /ai_activities/:id
  def show
    respond_to do |format|
      format.html # Display a single suggestion
      format.json { render json: @suggestion }
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
end
