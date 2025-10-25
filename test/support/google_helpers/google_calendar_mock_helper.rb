require_relative "mock_google_calendar_service"

module GoogleHelpers
  # Test helper module for Google Calendar mocking
  #
  # Usage:
  #   class MyServiceTest < ActiveSupport::TestCase
  #     include GoogleHelpers::GoogleCalendarMockHelper
  #
  #     test "something with mocked calendar" do
  #       with_mocked_google_calendar([]) do
  #         # test code here
  #       end
  #     end
  #   end
  module GoogleCalendarMockHelper
    # Temporarily replaces GoogleCalendarService with a mock for testing
    #
    # @param events [Array<Hash>] Array of event hashes with :summary, :start_time, :end_time
    # @yield Block to execute with mocked Google Calendar service
    #
    # @example
    #   with_mocked_google_calendar([]) do
    #     service = ActivitySchedulingService.new(user)
    #     agenda = service.generate_agenda
    #   end
    #
    # NOTE: This uses method override rather than dependency injection.
    # The ideal solution would be to inject GoogleCalendarService as a dependency:
    #
    #   def initialize(user, activities = nil, options = {}, calendar_service: GoogleCalendarService)
    #     @calendar_service = calendar_service
    #   end
    #
    # That would allow passing MockGoogleCalendarService directly in tests.
    def with_mocked_google_calendar(events)
      mock_service = GoogleHelpers::MockGoogleCalendarService.new(events)

      # Store and replace the new method
      original_new = GoogleCalendarService.method(:new)
      GoogleCalendarService.define_singleton_method(:new) { |*_args| mock_service }

      yield
    ensure
      # Restore original behavior
      GoogleCalendarService.define_singleton_method(:new, original_new)
    end
  end
end
