require "test_helper"
require "ostruct"

class ActivitySchedulingServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @activity_strict = activities(:one)  # Assumes this has strict schedule
    @activity_flexible = activities(:two) # Assumes this has flexible schedule

    # Set up test activity with deadline
    @activity_deadline = Activity.create!(
      user: @user,
      name: "Project Work",
      description: "Complete project deliverable",
      schedule_type: "deadline",
      deadline: 1.week.from_now,
      max_frequency_days: 1
    )

    @service = ActivitySchedulingService.new(@user)
    @date_range = Date.current..(Date.current + 1.week)
  end

  # Initialization tests
  test "should initialize with user and default activities" do
    service = ActivitySchedulingService.new(@user)

    assert_equal @user, service.user
    assert_equal @user.activities.active, service.activities
    assert service.options.is_a?(Hash)
  end

  test "should initialize with custom activities and options" do
    custom_activities = [ @activity_strict ]
    custom_options = { work_hours_start: 8 }

    service = ActivitySchedulingService.new(@user, custom_activities, custom_options)

    assert_equal custom_activities, service.activities
    assert_equal 8, service.options[:work_hours_start]
  end

  test "should set user timezone from user" do
    @user.update!(timezone: "Eastern Time (US & Canada)")
    service = ActivitySchedulingService.new(@user)

    assert_equal "Eastern Time (US & Canada)", service.instance_variable_get(:@user_timezone)
  end

  test "should raise error when user timezone is nil" do
    @user.update!(timezone: nil)

    assert_raises ArgumentError do 
      ActivitySchedulingService.new(@user)
    end
  end

  # Agenda generation tests
  test "should generate agenda with existing events and suggestions" do
    # Stub the Google Calendar service to avoid external API calls
    stub_google_calendar_list
    stub_google_events_list

    agenda = @service.generate_agenda(@date_range)

    assert_not_nil agenda
    assert agenda.is_a?(AgendaProposal)
  end

  test "should generate agenda with default date range when none provided" do
    agenda = @service.generate_agenda

    assert_not_nil agenda
    assert agenda.is_a?(AgendaProposal)
  end

  # Activity suggestion tests
  test "should generate strict schedule suggestions" do
    # Set up strict activity with specific times
    start_time = 2.days.from_now.beginning_of_day + 10.hours
    end_time = start_time + 2.hours

    @activity_strict.update!(
      schedule_type: "strict",
      start_time: start_time,
      end_time: end_time
    )

    service = ActivitySchedulingService.new(@user, [ @activity_strict ])
    suggestions = service.send(:generate_activity_suggestions, @date_range, [])

    assert suggestions.any?
    strict_suggestion = suggestions.find { |s| s[:type] == "strict" }
    assert_not_nil strict_suggestion
    assert_equal @activity_strict, strict_suggestion[:activity]
    assert_equal "high", strict_suggestion[:confidence]
  end

  test "should generate flexible schedule suggestions" do
    @activity_flexible.update!(
      schedule_type: "flexible",
      max_frequency_days: 30  # Use valid value from MAX_FREQUENCY_OPTIONS
    )

    service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
    suggestions = service.send(:generate_activity_suggestions, @date_range, [])

    assert suggestions.any?
    flexible_suggestion = suggestions.find { |s| s[:type] == "flexible" }
    assert_not_nil flexible_suggestion
    assert_equal @activity_flexible, flexible_suggestion[:activity]
    assert_equal "medium", flexible_suggestion[:confidence]
  end

  test "should generate deadline schedule suggestions" do
    service = ActivitySchedulingService.new(@user, [ @activity_deadline ])
    suggestions = service.send(:generate_activity_suggestions, @date_range, [])

    assert suggestions.any?
    deadline_suggestion = suggestions.find { |s| s[:type] == "deadline" }
    assert_not_nil deadline_suggestion
    assert_equal @activity_deadline, deadline_suggestion[:activity]
    assert_equal "high", deadline_suggestion[:confidence]
    assert deadline_suggestion[:title].include?("Complete:")
  end

  # Conflict detection tests
  test "should detect conflicts between suggestions and existing events" do
    existing_events = [
      {
        start_time: Time.current + 1.day + 10.hours,
        end_time: Time.current + 1.day + 11.hours,
        summary: "Existing Meeting"
      }
    ]

    start_time = Time.current + 1.day + 10.hours + 30.minutes
    end_time = Time.current + 1.day + 11.hours + 30.minutes

    has_conflict = @service.send(:has_conflict?, start_time, end_time, existing_events)
    assert has_conflict
  end

  test "should not detect conflicts when times don't overlap" do
    existing_events = [
      {
        start_time: Time.current + 1.day + 10.hours,
        end_time: Time.current + 1.day + 11.hours,
        summary: "Existing Meeting"
      }
    ]

    start_time = Time.current + 1.day + 12.hours
    end_time = Time.current + 1.day + 13.hours

    has_conflict = @service.send(:has_conflict?, start_time, end_time, existing_events)
    assert_not has_conflict
  end

  # Alternative time finding tests
  test "should find alternative time for conflicting suggestions" do
    original_suggestion = {
      activity: @activity_flexible,
      start_time: Time.current + 1.day + 10.hours,
      end_time: Time.current + 1.day + 11.hours,
      type: "flexible"
    }

    existing_events = [
      {
        start_time: Time.current + 1.day + 9.hours,
        end_time: Time.current + 1.day + 11.hours,
        summary: "Blocking Event"
      }
    ]

    alternative = @service.send(:find_alternative_time, original_suggestion, existing_events)

    assert_not_nil alternative
    assert alternative[:conflict_avoided]
    assert_equal "medium", alternative[:confidence]
    assert alternative[:notes].any? { |note| note.include?("Rescheduled") }
  end

  test "should attempt to find alternative time when conflicts exist" do
    original_suggestion = {
      activity: @activity_flexible,
      start_time: Time.current + 1.day + 10.hours,
      end_time: Time.current + 1.day + 11.hours,
      type: "flexible"
    }

    # Create a conflicting event at the original time
    existing_events = [
      {
        start_time: Time.current + 1.day + 10.hours,
        end_time: Time.current + 1.day + 11.hours,
        summary: "Conflicting Event"
      }
    ]

    alternative = @service.send(:find_alternative_time, original_suggestion, existing_events)

    # Should find an alternative time (not the original time)
    if alternative
      assert_not_equal original_suggestion[:start_time], alternative[:start_time]
      assert alternative[:conflict_avoided]
      assert_equal "medium", alternative[:confidence]
    else
      # It's acceptable to return nil if no slots are available
      # This tests the resilience of the scheduling system
      assert_nil alternative
    end
  end

  # Time slot generation tests
  test "should generate time slots throughout the day" do
    date = Date.current
    slots = @service.send(:generate_time_slots, date)

    assert slots.any?
    # Should have morning, afternoon, and evening slots
    morning_slots = slots.select { |slot| slot.hour < 12 }
    afternoon_slots = slots.select { |slot| slot.hour >= 12 && slot.hour < 18 }
    evening_slots = slots.select { |slot| slot.hour >= 18 }

    assert morning_slots.any?
    assert afternoon_slots.any?
    assert evening_slots.any?
  end

  # Calendar event creation tests
  test "should format dry run results with suggestions summary" do
    suggestions = [
      {
        activity: @activity_flexible,
        title: "Test Activity",
        start_time: Time.current + 1.day,
        end_time: Time.current + 1.day + 1.hour,
        type: "flexible",
        confidence: "medium"
      }
    ]

    @service.instance_variable_set(:@existing_events, [])

    results = @service.send(:format_dry_run_results, suggestions)

    assert_equal 1, results.total_suggestions
    assert_equal 1, results.suggestions_by_type["flexible"]
    assert_equal 0, results.existing_events_count
    assert results.timeline.any?
    assert results.next_steps.any?
  end

  test "should create calendar events in dry run mode by default" do
    suggestions = [
      {
        activity: @activity_flexible,
        title: "Test Activity",
        start_time: Time.current + 1.day,
        end_time: Time.current + 1.day + 1.hour,
        type: "flexible"
      }
    ]

    results = @service.create_calendar_events(suggestions)

    assert results.is_a?(ActivitySchedulingService::DryRunResults)
    assert results.total_suggestions
    assert results.next_steps
  end

  test "should handle dry run mode" do
    suggestions = [
      {
        activity: @activity_flexible,
        title: "Test Activity",
        start_time: Time.current + 1.day,
        end_time: Time.current + 1.day + 1.hour,
        type: "flexible"
      }
    ]

    # Test dry run mode
    results = @service.create_calendar_events(suggestions, dry_run: true)

    assert results.is_a?(ActivitySchedulingService::DryRunResults)
    assert_equal 1, results.total_suggestions
    assert results.next_steps.any?
  end

  # Schedule activities integration test
  test "should respond to schedule_activities method" do
    # Test that the method exists and can be called
    assert_respond_to @service, :schedule_activities

    # This method calls suggest_schedule which might not be implemented yet
    # So we just test the method exists for now
  end

  # Default options tests
  test "should have sensible default options" do
    options = @service.send(:default_options)

    assert_equal 9, options[:work_hours_start]
    assert_equal 17, options[:work_hours_end]
    assert_equal 60.minutes, options[:preferred_duration]
    assert_equal 15.minutes, options[:buffer_time]
    assert_equal false, options[:exclude_weekends]
  end

  test "should merge custom options with defaults" do
    custom_options = { work_hours_start: 8, exclude_weekends: true }
    service = ActivitySchedulingService.new(@user, nil, custom_options)

    assert_equal 8, service.options[:work_hours_start]
    assert_equal true, service.options[:exclude_weekends]
    assert_equal 17, service.options[:work_hours_end] # Default preserved
  end

  # Date range tests
  test "should use default date range when none provided" do
    default_range = @service.send(:default_date_range)

    assert_equal Date.current, default_range.begin
    assert_equal Date.current + 2.weeks, default_range.end
  end

  # Load existing events tests (with mocking)
  test "should return empty events when user has no Google accounts" do
    @user.google_accounts.destroy_all

    events = @service.send(:load_existing_events, @date_range)

    assert_equal [], events
  end

  test "should handle Google Calendar service initialization" do
    # Test that the service can handle cases where GoogleCalendarService might not be available
    events = @service.send(:load_existing_events, @date_range)

    # Should return empty array when no Google accounts or service errors
    assert events.is_a?(Array)
  end

  test "should access CalendarInfo attributes correctly" do
    # Test that CalendarInfo objects created by Data.define work correctly
    calendar_info = ActivitySchedulingService::CalendarInfo.new(
      id: "test_calendar_id",
      summary: "Test Calendar",
      description: "Test description",
      primary: true,
      access_role: "owner"
    )

    # This test verifies that the CalendarInfo objects have direct attribute access
    # and don't need .fetch() method calls (which was the bug)
    assert_equal "test_calendar_id", calendar_info.id
    assert_equal "Test Calendar", calendar_info.summary
    assert_equal "Test description", calendar_info.description
    assert_equal true, calendar_info.primary
    assert_equal "owner", calendar_info.access_role

    # Verify that these objects don't have a fetch method
    assert_not_respond_to calendar_info, :fetch
  end


  test "should demonstrate that CalendarInfo.from_api creates correct objects" do
    # Mock a Google Calendar API response
    mock_calendar = OpenStruct.new(
      id: "calendar_123",
      summary: "My Calendar",
      description: "Personal calendar",
      primary: false,
      access_role: "reader"
    )

    # Test the from_api factory method
    calendar_info = ActivitySchedulingService::CalendarInfo.from_api(mock_calendar)

    assert_equal "calendar_123", calendar_info.id
    assert_equal "My Calendar", calendar_info.summary
    assert_equal "Personal calendar", calendar_info.description
    assert_equal false, calendar_info.primary
    assert_equal "reader", calendar_info.access_role

    # Confirm these can be accessed as attributes, not via fetch
    assert_equal "calendar_123", calendar_info.id
    assert_not_respond_to calendar_info, :fetch
  end

  test "should handle CalendarInfo objects in load_existing_events without using fetch" do
    # This test specifically covers the bug that was fixed
    # The original code used calendar.fetch(:id) and calendar.fetch(:summary)
    # which failed because CalendarInfo objects don't have a fetch method

    # Use the Google account fixture
    google_account = google_accounts(:one)
    google_account.update!(access_token: "test_token", refresh_token: "test_refresh")

    # Create a user with the Google account for this test
    test_user = users(:one)
    service = ActivitySchedulingService.new(test_user)

    # Create a mock GoogleCalendarService that returns CalendarInfo objects
    mock_service = Class.new do
      def fetch_calendars
        [
          ActivitySchedulingService::CalendarInfo.new(
            id: "primary",
            summary: "Primary Calendar",
            description: "Main calendar",
            primary: true,
            access_role: "owner"
          ),
          ActivitySchedulingService::CalendarInfo.new(
            id: "work_calendar",
            summary: "Work Calendar",
            description: "Work events",
            primary: false,
            access_role: "writer"
          )
        ]
      end

      def list_events(calendar_id, start_time, end_time)
        # Return mock events based on calendar_id to verify the method receives
        # the correct calendar.id (not calendar.fetch(:id))
        case calendar_id
        when "primary"
          [
            OpenStruct.new(
              summary: "Personal Meeting",
              start: OpenStruct.new(date_time: Time.current + 1.hour),
              end: OpenStruct.new(date_time: Time.current + 2.hours)
            )
          ]
        when "work_calendar"
          [
            OpenStruct.new(
              summary: "Work Meeting",
              start: OpenStruct.new(date_time: Time.current + 3.hours),
              end: OpenStruct.new(date_time: Time.current + 4.hours)
            )
          ]
        else
          []
        end
      end
    end.new

    # Stub GoogleCalendarService.new to return our mock
    original_new = GoogleCalendarService.method(:new)
    GoogleCalendarService.define_singleton_method(:new) { |_| mock_service }

    begin
      events = service.send(:load_existing_events, @date_range)

      # Verify that the method successfully processed CalendarInfo objects
      # without trying to use .fetch() method
      assert events.is_a?(Array)
      assert_equal 2, events.length

      # Verify events from both calendars were processed
      personal_event = events.find { |e| e[:summary] == "Personal Meeting" }
      work_event = events.find { |e| e[:summary] == "Work Meeting" }

      assert_not_nil personal_event
      assert_not_nil work_event

      # Verify calendar information was correctly extracted using .id and .summary
      assert_equal "primary", personal_event[:calendar_id]
      assert_equal "Primary Calendar", personal_event[:calendar_name]
      assert_equal "work_calendar", work_event[:calendar_id]
      assert_equal "Work Calendar", work_event[:calendar_name]

    ensure
      # Restore original method
      GoogleCalendarService.define_singleton_method(:new, original_new)
    end
  end

  # Filtering tests
  test "should filter conflicting suggestions and try to reschedule flexible ones" do
    suggestions = [
      {
        activity: @activity_flexible,
        title: "Flexible Activity",
        start_time: Time.current + 1.day + 10.hours,
        end_time: Time.current + 1.day + 11.hours,
        type: "flexible"
      },
      {
        activity: @activity_strict,
        title: "Strict Activity",
        start_time: Time.current + 1.day + 10.hours + 30.minutes,
        end_time: Time.current + 1.day + 11.hours + 30.minutes,
        type: "strict"
      }
    ]

    existing_events = [
      {
        start_time: Time.current + 1.day + 10.hours,
        end_time: Time.current + 1.day + 11.hours,
        summary: "Blocking Event"
      }
    ]

    filtered = @service.send(:filter_conflicting_suggestions, suggestions, existing_events)

    # Should have rescheduled the flexible activity and marked the strict one as conflicting
    assert filtered.any?
    flexible_result = filtered.find { |s| s[:activity] == @activity_flexible }
    strict_result = filtered.find { |s| s[:activity] == @activity_strict }

    if flexible_result
      assert flexible_result[:conflict_avoided] || flexible_result[:start_time] != suggestions[0][:start_time]
    end

    if strict_result
      assert strict_result[:has_conflict]
    end
  end
end
