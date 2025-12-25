# Controller for browsing and discovering external events from RSS feeds.
# Handles event listing with filtering, search, and calendar integration.
class EventsController < ApplicationController
  before_action :set_event, only: [ :show, :add_to_calendar ]
  before_action :authenticate_user!, only: [ :add_to_calendar ]

  PER_PAGE = 24

  # Lists all upcoming external events with filtering and pagination
  # @return [void] Sets @events instance variable for view rendering
  def index
    @events = ExternalEvent.active.upcoming.order(start_time: :asc)

    # Apply filters
    apply_filters

    # Simple pagination
    @page = (params[:page] || 1).to_i
    @total_count = @events.count
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
    @events = @events.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)

    # Get free weekends if user is authenticated
    @free_weekends = user_signed_in? ? find_free_weekends : []
  end

  # Displays a single external event
  # @return [void] Event is set by before_action, renders show view
  def show
    # Event is set by before_action
  end

  # Adds an external event to the user's calendar as an Activity
  # @return [void] Redirects to events index with success/error message
  def add_to_calendar
    # Check if user already has this event
    existing_activity = current_user.activities.find_by(source_url: @event.source_url)

    if existing_activity
      redirect_to events_path, alert: "You've already added this event to your calendar."
      return
    end

    # Create Activity from event
    activity = current_user.activities.build(@event.to_activity_params(current_user))

    if activity.save
      # Optionally sync to Google Calendar
      if current_user.active_google_account && !current_user.active_google_account.needs_refresh?
        sync_to_google_calendar(activity)
      end

      redirect_to events_path, notice: "Event added to your calendar!"
    else
      redirect_to events_path, alert: "Failed to add event: #{activity.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_event
    @event = ExternalEvent.active.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to events_path, alert: "Event not found."
  end

  def apply_filters
    filter_options = build_filter_options
    @events = @events.apply_filters(filter_options)
  end

  def build_filter_options
    filter_params = params.slice(:start_date, :end_date, :weekends_only, :free_only, :price_max, :category, :search)

    {}.tap do |options|
      # Parse date range
      if filter_params[:start_date].present? && filter_params[:end_date].present?
        begin
          options[:start_date] = Date.parse(filter_params[:start_date])
          options[:end_date] = Date.parse(filter_params[:end_date])
        rescue Date::Error
          flash.now[:alert] = "Invalid date format"
        end
      end

      # Boolean filters
      options[:weekends_only] = filter_params[:weekends_only] == "true"
      options[:free_only] = filter_params[:free_only] == "true"

      # Price max
      options[:price_max] = filter_params[:price_max].to_f if filter_params[:price_max].present?

      # Text filters
      options[:category] = filter_params[:category] if filter_params[:category].present?
      options[:search] = filter_params[:search] if filter_params[:search].present?
    end
  end

  def find_free_weekends
    # Get next 3 months of weekends
    weekends = []
    current_date = Date.current

    12.times do |i|
      week_start = current_date + i.weeks
      saturday = week_start.beginning_of_week(:sunday) + 6.days
      sunday = saturday + 1.day

      # Check if user has any activities on this weekend
      has_activities = current_user.activities
                                    .active
                                    .where(schedule_type: "strict")
                                    .where("start_time::date IN (?)", [ saturday, sunday ])
                                    .exists?

      weekends << { saturday: saturday, sunday: sunday } unless has_activities
    end

    weekends.first(5) # Return first 5 free weekends
  end

  def sync_to_google_calendar(activity)
    GoogleCalendarService.new(current_user.active_google_account).create_event(
      summary: activity.name,
      description: activity.description,
      start_time: activity.start_time,
      end_time: activity.end_time,
      timezone: current_user.timezone
    )
  rescue StandardError => e
    Rails.logger.error("Failed to sync to Google Calendar: #{e.message}")
    # Don't fail the whole operation if calendar sync fails
  end
end
