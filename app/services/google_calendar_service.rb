require "google/apis/calendar_v3"
require "googleauth"

class GoogleCalendarService
  def initialize(google_account)
    @google_account = google_account
    @service = Google::Apis::CalendarV3::CalendarService.new
    authorize!
  end

  # Fetch all calendars for the user
  def fetch_calendars
    calendar_list = @service.list_calendar_lists
    calendars = calendar_list.items.map do |calendar|
      {
        id: calendar.id,
        summary: calendar.summary,
        description: calendar.description,
        primary: calendar.primary || false,
        access_role: calendar.access_role
      }
    end

    # Update the stored calendar list
    @google_account.calendars = calendars
    @google_account.save!

    calendars
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Google Calendar authorization error: #{e.message}"
    refresh_token_and_retry { fetch_calendars }
  end

  # Create a calendar event
  def create_event(calendar_id, event_data)
    event = Google::Apis::CalendarV3::Event.new(
      summary: event_data[:title],
      description: event_data[:description],
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: event_data[:start_time]&.iso8601,
        time_zone: event_data[:timezone] || "America/Los_Angeles"
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: event_data[:end_time]&.iso8601,
        time_zone: event_data[:timezone] || "America/Los_Angeles"
      )
    )

    @service.insert_event(calendar_id, event)
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Google Calendar authorization error: #{e.message}"
    refresh_token_and_retry { create_event(calendar_id, event_data) }
  end

  # Get events from a calendar within a date range
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
  def update_event(calendar_id, event_id, event_data)
    event = @service.get_event(calendar_id, event_id)

    event.summary = event_data[:title] if event_data[:title]
    event.description = event_data[:description] if event_data[:description]

    if event_data[:start_time]
      event.start = Google::Apis::CalendarV3::EventDateTime.new(
        date_time: event_data[:start_time].iso8601,
        time_zone: event_data[:timezone] || "America/Los_Angeles"
      )
    end

    if event_data[:end_time]
      event.end = Google::Apis::CalendarV3::EventDateTime.new(
        date_time: event_data[:end_time].iso8601,
        time_zone: event_data[:timezone] || "America/Los_Angeles"
      )
    end

    @service.update_event(calendar_id, event_id, event)
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Google Calendar authorization error: #{e.message}"
    refresh_token_and_retry { update_event(calendar_id, event_id, event_data) }
  end

  # Delete an event
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

  # Build the authorization object
  def build_authorization
    auth = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google[:client_id],
      client_secret: Rails.application.credentials.google[:client_secret],
      scope: [ "https://www.googleapis.com/auth/calendar" ],
      refresh_token: @google_account.refresh_token
    )

    auth.access_token = @google_account.access_token
    auth.expires_at = @google_account.expires_at
    auth
  end

  # Refresh the access token using the refresh token
  def refresh_access_token
    return unless @google_account.refresh_token.present?

    auth = build_authorization

    begin
      auth.refresh!

      @google_account.update!(
        access_token: auth.access_token,
        expires_at: auth.expires_at
      )

      Rails.logger.info "Successfully refreshed Google access token for user #{@google_account.user_id}"
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Failed to refresh Google access token: #{e.message}"
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
