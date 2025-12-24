# Controller for browsing and discovering external events from RSS feeds.
# Handles event listing with filtering, search, and calendar integration.
class EventsController < ApplicationController
  before_action :set_event, only: [ :show, :add_to_calendar ]
  before_action :authenticate_user!, only: [ :add_to_calendar ]

  PER_PAGE = 24

  # Lists all upcoming external events with filtering and pagination
  # @return [void] Sets @events instance variable for view rendering
  def index
    @events = ExternalEvent.active.order(start_time: :desc)

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
      sync_to_google_calendar(activity) if current_user.google_account&.valid_credentials?

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
    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
      @events = @events.by_date_range(start_date, end_date)
    end

    # Weekends only filter
    if params[:weekends_only] == "true"
      @events = @events.weekends_only
    end

    # Free events filter
    if params[:free_only] == "true"
      @events = @events.free_only
    end

    # Price max filter
    if params[:price_max].present?
      price_max = params[:price_max].to_f
      @events = @events.where("price IS NULL OR price <= ?", price_max)
    end

    # Category filter
    if params[:category].present?
      @events = @events.where("? = ANY(category_tags)", params[:category])
    end

    # Search filter
    if params[:search].present?
      @events = @events.search_by_text(params[:search])
    end
  rescue Date::Error
    # Invalid date format, ignore filter
    flash.now[:alert] = "Invalid date format"
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
    GoogleCalendarService.new(current_user.google_account).create_event(
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
