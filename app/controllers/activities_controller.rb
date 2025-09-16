class ActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_activity, only: [:show, :edit, :update, :destroy]
  before_action :ensure_owner, only: [:edit, :update, :destroy]

  def index
    @activities = current_user.activities.active.includes(:user)
                             .order(created_at: :desc)
  end

  def show
    # Activity is set by before_action
  end

  def new
    @activity = current_user.activities.build
  end

  def create
    @activity = current_user.activities.build(activity_params)

    if @activity.save
      redirect_to @activity, notice: 'Activity was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Activity is set by before_action and ownership is verified
  end

  def update
    if @activity.update(activity_params)
      redirect_to @activity, notice: 'Activity was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @activity.archive!
    redirect_to activities_url, notice: 'Activity was successfully archived.'
  end

  private

  def set_activity
    @activity = Activity.active.find_by!(slug: params[:id])
  end

  def ensure_owner
    unless @activity.user == current_user
      redirect_to activities_path, alert: 'You can only edit your own activities.'
    end
  end

  def activity_params
    params.require(:activity).permit(
      :name, :description, :schedule_type, :start_time, :end_time,
      :deadline, :max_frequency_days, links: []
    )
  end
end
