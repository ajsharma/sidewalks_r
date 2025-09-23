# Controller for managing user activities.
# Handles CRUD operations for activities with proper authorization.
class ActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_activity, only: [ :show, :edit, :update, :destroy ]
  before_action :ensure_owner, only: [ :edit, :update, :destroy ]

  # Lists all active activities for the current user
  # @return [void] Sets @activities instance variable for view rendering
  def index
    @activities = current_user.activities.active.order(created_at: :desc)
  end

  # Displays a single activity
  # @return [void] Activity is set by before_action, renders show view
  def show
    # Activity is set by before_action
  end

  # Renders form for creating a new activity
  # @return [void] Sets @activity instance variable for form rendering
  def new
    @activity = current_user.activities.build
  end

  # Creates a new activity for the current user
  # @return [void] Redirects to activity on success, renders new form on failure
  def create
    @activity = current_user.activities.build(activity_params)

    if @activity.save
      redirect_to @activity, notice: "Activity was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # Renders form for editing an existing activity
  # @return [void] Activity is set by before_action and ownership is verified
  def edit
    # Activity is set by before_action and ownership is verified
  end

  # Updates an existing activity with new parameters
  # @return [void] Redirects to activity on success, renders edit form on failure
  def update
    if @activity.update(activity_params)
      redirect_to @activity, notice: "Activity was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Archives an activity (soft delete)
  # @return [void] Redirects to activities index with success notice
  def destroy
    if @activity.archive
      redirect_to activities_url, notice: "Activity was successfully archived."
    else
      redirect_to activities_url, alert: "Failed to archive activity."
    end
  end

  private

  def set_activity
    @activity = current_user.activities.active.find_by!(slug: params[:id])
  end

  def ensure_owner
    unless Activity.owned_by(current_user).exists?(@activity.id)
      redirect_to activities_path, alert: "You can only edit your own activities."
    end
  end

  def activity_params
    params.require(:activity).permit(
      :name, :description, :schedule_type, :start_time, :end_time,
      :deadline, :max_frequency_days, links: []
    )
  end
end
