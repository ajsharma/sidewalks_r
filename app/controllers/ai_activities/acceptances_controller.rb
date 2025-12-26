# Controller for accepting AI activity suggestions and creating activities
# :reek:DuplicateMethodCall
# :reek:InstanceVariableAssumption
module AiActivities
  # Handles acceptance of AI suggestions and creation of activities
  class AcceptancesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_suggestion

    # POST /ai_activities/:ai_activity_id/acceptance
    # Accepts the suggestion and creates an Activity
    def create
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
