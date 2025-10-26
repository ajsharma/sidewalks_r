require "google/apis/calendar_v3"
require "googleauth"

# Service for Google Calendar API interactions.
# Handles authentication, calendar access, and event management.
class GoogleCalendarService
  # General error
  class Error < RuntimeError; end
  # Custom exception for timezone conversion errors
  class InvalidTimezoneError < Error; end

  # Converts Rails timezone name to IANA timezone identifier for Google Calendar API
  # @param rails_timezone [String] Rails timezone name (e.g., "Pacific Time (US & Canada)")
  # @return [String] IANA timezone identifier (e.g., "America/Los_Angeles")
  # @raise [InvalidTimezoneError] if timezone is invalid or cannot be converted
  def self.to_iana_timezone(rails_timezone)
    iana_timezone = ActiveSupport::TimeZone[rails_timezone]&.tzinfo&.identifier
    unless iana_timezone
      raise InvalidTimezoneError, "Invalid timezone: #{rails_timezone}"
    end
    iana_timezone
  end

  # Initializes the Google Calendar service with authentication
  # @param google_account [GoogleAccount] authenticated Google account for API access
  # @return [GoogleCalendarService] new instance of the service
  def initialize(google_account)
    @google_account = google_account
    @service = Google::Apis::CalendarV3::CalendarService.new
    authorize!
  end

  # Fetch all calendars for the user
  # @return [Array<ActivitySchedulingService::CalendarInfo>] array of calendar info data objects
  def fetch_calendars
    calendar_list = @service.list_calendar_lists
    calendars = calendar_list.items.map do |calendar|
      ActivitySchedulingService::CalendarInfo.from_api(calendar)
    end

    # Update the stored calendar list (convert to hash for storage)
    @google_account.calendars = calendars.map(&:to_h)
    @google_account.save!

    calendars
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Google Calendar authorization error: #{e.message}"
    refresh_token_and_retry { fetch_calendars }
  end

  # Create a calendar event
  # @param calendar_id [String] Google Calendar ID to create event in
  # @param event_data [Hash] event data with :title, :description, :start_time, :end_time, :timezone
  # @return [Google::Apis::CalendarV3::Event] created event object
  def create_event(calendar_id, event_data)
    timezone = event_data[:timezone] || "America/Los_Angeles"

    event = Google::Apis::CalendarV3::Event.new(
      summary: event_data[:title],
      description: event_data[:description],
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: event_data[:start_time]&.iso8601,
        time_zone: timezone
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: event_data[:end_time]&.iso8601,
        time_zone: timezone
      )
    )

    @service.insert_event(calendar_id, event)
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Google Calendar authorization error: #{e.message}"
    refresh_token_and_retry { create_event(calendar_id, event_data) }
  end

  # Get events from a calendar within a date range
  # @param calendar_id [String] Google Calendar ID to fetch events from
  # @param start_date [Time] start of date range
  # @param end_date [Time] end of date range
  # @return [Array<Google::Apis::CalendarV3::Event>] array of events in the date range
  def list_events(calendar_id, start_date, end_date)
    @service.list_events(
      calendar_id,
      time_min: start_date.iso8601,
      time_max: end_date.iso8601,
      single_events: true,
      order_by: "startTime"
    ).items
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Google Calendar authorization error: #{e.message}"
    refresh_token_and_retry { list_events(calendar_id, start_date, end_date) }
  end

  # Update an existing event
  # @param calendar_id [String] Google Calendar ID containing the event
  # @param event_id [String] Google Calendar event ID to update
  # @param event_data [Hash] updated event data with :title, :description, :start_time, :end_time, :timezone
  # @return [Google::Apis::CalendarV3::Event] updated event object
  def update_event(calendar_id, event_id, event_data)
    event = @service.get_event(calendar_id, event_id)
    timezone = event_data[:timezone] || "America/Los_Angeles"

    title = event_data[:title]
    description = event_data[:description]
    start_time = event_data[:start_time]
    end_time = event_data[:end_time]

    event.summary = title if title
    event.description = description if description

    if start_time
      event.start = Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time.iso8601,
        time_zone: timezone
      )
    end

    if end_time
      event.end = Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time.iso8601,
        time_zone: timezone
      )
    end

    @service.update_event(calendar_id, event_id, event)
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Google Calendar authorization error: #{e.message}"
    refresh_token_and_retry { update_event(calendar_id, event_id, event_data) }
  end

  # Delete an event
  # @param calendar_id [String] Google Calendar ID containing the event
  # @param event_id [String] Google Calendar event ID to delete
  # @return [void] deletes the event, no return value
  def delete_event(calendar_id, event_id)
    @service.delete_event(calendar_id, event_id)
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Google Calendar authorization error: #{e.message}"
    refresh_token_and_retry { delete_event(calendar_id, event_id) }
  end

  private

  # Set up authorization for the Google Calendar API
  def authorize!
    if @google_account.needs_refresh?
      refresh_access_token
    end

    @service.authorization = build_authorization
  end

  def authorize
    if @google_account.needs_refresh?
      refresh_access_token
    end

    @service.authorization = build_authorization
    true
  rescue => e
    Rails.logger.error "Google Calendar authorization failed: #{e.message}"
    false
  end

  # Build the authorization object
  def build_authorization
    google_credentials = Rails.application.credentials.google

    auth = Google::Auth::UserRefreshCredentials.new(
      client_id: google_credentials[:client_id],
      client_secret: google_credentials[:client_secret],
      scope: [ "https://www.googleapis.com/auth/calendar" ],
      refresh_token: @google_account.refresh_token
    )

    auth.access_token = @google_account.access_token
    auth.expires_at = @google_account.expires_at
    auth
  end

  # Refresh the access token using the refresh token
  def refresh_access_token
    return unless @google_account.refresh_token?

    auth = build_authorization

    begin
      auth.refresh!

      @google_account.update!(
        access_token: auth.access_token,
        expires_at: auth.expires_at
      )

      logger = Rails.logger
      logger.info "Successfully refreshed Google access token for user #{@google_account.user_id}"
    rescue Google::Apis::AuthorizationError => e
      logger.error "Failed to refresh Google access token: #{e.message}"
      # Mark the account as needing re-authorization
      @google_account.update!(access_token: nil, refresh_token: nil)
      raise
    end
  end

  # Retry a method call after refreshing the token
  def refresh_token_and_retry(&block)
    refresh_access_token
    authorize!
    yield
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Failed to refresh and retry Google Calendar operation: #{e.message}"
    raise
  end
end
