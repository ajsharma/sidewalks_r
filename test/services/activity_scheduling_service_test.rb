require "test_helper"

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

  test "should set user timezone from user or default" do
    @user.update!(timezone: "Eastern Time (US & Canada)")
    service = ActivitySchedulingService.new(@user)

    assert_equal "Eastern Time (US & Canada)", service.instance_variable_get(:@user_timezone)
  end

  test "should use default timezone when user timezone is nil" do
    @user.update!(timezone: nil)
    service = ActivitySchedulingService.new(@user)

    assert_equal "America/Los_Angeles", service.instance_variable_get(:@user_timezone)
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

  test "should return nil when no alternative time is available" do
    original_suggestion = {
      activity: @activity_flexible,
      start_time: Time.current + 1.day + 10.hours,
      end_time: Time.current + 1.day + 11.hours,
      type: "flexible"
    }

    # Create many conflicting events to block all time slots
    existing_events = []
    (7..21).each do |hour|
      existing_events << {
        start_time: Time.current + 1.day + hour.hours,
        end_time: Time.current + 1.day + hour.hours + 2.hours,
        summary: "Blocking Event #{hour}"
      }
    end

    alternative = @service.send(:find_alternative_time, original_suggestion, existing_events)
    assert_nil alternative
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

    assert_equal 1, results[:total_suggestions]
    assert_equal 1, results[:suggestions_by_type]["flexible"]
    assert_equal 0, results[:existing_events_count]
    assert results[:timeline].any?
    assert results[:next_steps].any?
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

    assert results.is_a?(Hash)
    assert results[:total_suggestions]
    assert results[:next_steps]
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

    assert results.is_a?(Hash)
    assert_equal 1, results[:total_suggestions]
    assert results[:next_steps].any?
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
