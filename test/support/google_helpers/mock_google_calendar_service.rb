module GoogleHelpers
  # Mock Google Calendar Service for testing
  # Provides a test double that mimics GoogleCalendarService behavior without external API calls
  class MockGoogleCalendarService
    def initialize(events = [])
      @events = events
    end

    def fetch_calendars
      [
        ActivitySchedulingService::CalendarInfo.new(
          id: "primary",
          summary: "Primary Calendar",
          description: "Main calendar",
          primary: true,
          access_role: "owner"
        )
      ]
    end

    def list_events(_calendar_id, _start_time, _end_time)
      require "ostruct"

      @events.map do |event_data|
        OpenStruct.new(
          summary: event_data[:summary],
          start: OpenStruct.new(date_time: event_data[:start_time]),
          end: OpenStruct.new(date_time: event_data[:end_time])
        )
      end
    end
  end
end
