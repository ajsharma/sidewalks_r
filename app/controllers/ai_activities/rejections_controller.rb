# Controller for rejecting AI activity suggestions
# :reek:InstanceVariableAssumption
module AiActivities
  # Handles rejection/dismissal of AI suggestions
  class RejectionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_suggestion

    # POST /ai_activities/:ai_activity_id/rejection
    # Rejects the suggestion
    def create
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

    private

    def set_suggestion
      @suggestion = current_user.ai_suggestions.find(params[:ai_activity_id])
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.json { render json: { error: "Suggestion not found" }, status: :not_found }
        format.html { redirect_to ai_activities_path, alert: "Suggestion not found" }
      end
    end
  end
end
