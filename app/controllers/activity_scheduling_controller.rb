# Controller for activity scheduling and calendar integration.
# Handles Google Calendar API integration and agenda generation.
class ActivitySchedulingController < ApplicationController
  before_action :authenticate_user!
  before_action :preload_associations

  # Displays the scheduling interface with current agenda and suggestions
  # GET /schedule
  def show
    @scheduling_service = ActivitySchedulingService.new(current_user)
    @date_range = parse_date_range
    @agenda = @scheduling_service.generate_agenda(@date_range)
  end

  # Creates a single calendar event from a specific activity suggestion
  # POST /schedule/events
  # Expects params: activity_id, start_time, end_time
  def create
    activity = current_user.activities.find(params[:activity_id])
    activity_name = activity.name

    # Parse and validate times
    time_zone = Time.zone
    start_time = time_zone.parse(params[:start_time])
    end_time = time_zone.parse(params[:end_time])

    # Check if parsing returned nil (invalid format)
    if start_time.nil? || end_time.nil?
      redirect_to schedule_path, alert: "Invalid date/time format" and return
    end

    # Create event directly using Google Calendar service
    google_service = GoogleCalendarService.new(current_user.active_google_account)

    begin
      event_data = {
        title: params[:title] || activity_name,
        description: activity.description,
        start_time: start_time,
        end_time: end_time,
        timezone: current_user.timezone
      }

      event = google_service.create_event("primary", event_data)

      redirect_to schedule_path, notice: "Successfully added '#{activity_name}' to your calendar!"
    rescue Google::Auth::AuthorizationError, Google::Apis::ClientError => e
      Rails.logger.error "Failed to create calendar event: #{e.message}"
      redirect_to schedule_path, alert: "Failed to create calendar event. Please check your Google Calendar connection."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to schedule_path, alert: "Activity not found"
  end

  # Batch creates calendar events from multiple activity suggestions
  # POST /schedule/events/batch
  # Accepts dry_run parameter: if not "false", shows preview instead of creating events
  def batch
    @scheduling_service = ActivitySchedulingService.new(current_user)
    @date_range = parse_date_range
    @agenda = @scheduling_service.generate_agenda(@date_range)
    suggestions = @agenda.suggestions

    if params[:dry_run] != "false"
      # Dry run mode - show suggestions
      @results = @scheduling_service.create_calendar_events(suggestions, dry_run: true)
      render :preview
    else
      # Actually create calendar events
      @results = @scheduling_service.create_calendar_events(suggestions, dry_run: false)

      results_by_status = @results.group_by { |result| result[:status] }
      success_count = results_by_status["created"]&.count || 0
      failure_count = results_by_status["failed"]&.count || 0

      if failure_count == 0
        redirect_to schedule_path, notice: "Successfully created #{success_count} calendar events!"
      else
        redirect_to schedule_path, alert: "Created #{success_count} events, but #{failure_count} failed. Check your Google Calendar connection."
      end
    end
  end


  private

  def preload_associations
    # Preload google_accounts to avoid N+1 queries in the view
    current_user.google_accounts.load if current_user.persisted?
  end

  def parse_date_range
    current_date = Date.current
    default_end_date = current_date + 2.weeks

    start_date_param = params[:start_date]
    end_date_param = params[:end_date]

    start_date = start_date_param.present? ? Date.parse(start_date_param) : current_date
    end_date = end_date_param.present? ? Date.parse(end_date_param) : default_end_date

    start_date..end_date
  rescue ArgumentError
    current_date..default_end_date
  end
end
