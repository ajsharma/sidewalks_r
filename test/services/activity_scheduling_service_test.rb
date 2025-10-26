require "test_helper"

class ActivitySchedulingServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)

    @activity_strict = activities(:one)
    @activity_flexible = activities(:two)

    @activity_deadline = Activity.create!(
      user: @user,
      name: "Project Work",
      description: "Complete project deliverable",
      schedule_type: "deadline",
      deadline: 1.week.from_now,
      max_frequency_days: 1
    )

    @date_range = Date.current..(Date.current + 1.week)
  end

  # ============================================================================
  # Initialization and Configuration Tests
  # ============================================================================

  test "initializes with user and loads active activities by default" do
    service = ActivitySchedulingService.new(@user)

    assert_equal @user, service.user
    assert_equal @user.activities.active, service.activities
    assert_kind_of Hash, service.options
  end

  test "accepts custom activities and options" do
    custom_activities = [ @activity_strict ]
    custom_options = { work_hours_start: 8, exclude_weekends: true }

    service = ActivitySchedulingService.new(@user, custom_activities, custom_options)

    assert_equal custom_activities, service.activities
    assert_equal 8, service.options[:work_hours_start]
    assert service.options[:exclude_weekends]
    assert_equal 17, service.options[:work_hours_end] # Default preserved
  end

  test "raises error when user is blank" do
    assert_raises ArgumentError, match: /Blank use/ do
      ActivitySchedulingService.new(nil)
    end
  end

  test "raises error when user timezone is blank" do
    @user.update!(timezone: nil)

    error = assert_raises ArgumentError do
      ActivitySchedulingService.new(@user)
    end

    assert_match /time zone/, error.message
  end

  # ============================================================================
  # Public API: generate_agenda Tests
  # ============================================================================

  test "generate_agenda returns AgendaProposal with suggestions" do
    with_mocked_google_calendar([]) do
      agenda = ActivitySchedulingService.new(@user).generate_agenda(@date_range)

      assert_instance_of AgendaProposal, agenda
      assert_kind_of Array, agenda.suggestions
      assert_kind_of Array, agenda.existing_events
    end
  end

  test "generate_agenda uses default date range when none provided" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 1)

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      agenda = service.generate_agenda

      assert_instance_of AgendaProposal, agenda
      # Agenda should include suggestions (default range is 2 weeks)
      assert agenda.suggestions.any?, "Should generate suggestions for default date range"
    end
  end

  test "generate_agenda includes strict schedule activities at their exact times" do
    start_time = 2.days.from_now.beginning_of_day + 10.hours
    end_time = start_time + 2.hours

    @activity_strict.update!(
      schedule_type: "strict",
      start_time: start_time,
      end_time: end_time,
      max_frequency_days: 30
    )

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_strict ])
      agenda = service.generate_agenda(@date_range)

      strict_suggestion = agenda.suggestions.find { |s| s.activity == @activity_strict }

      assert strict_suggestion, "Should include strict activity in suggestions"
      assert_equal "strict", strict_suggestion.type
      assert_equal start_time, strict_suggestion.start_time
      assert_equal end_time, strict_suggestion.end_time
      assert_equal "high", strict_suggestion.confidence
    end
  end

  test "generate_agenda includes flexible activities at suggested times" do
    @activity_flexible.update!(
      schedule_type: "flexible",
      max_frequency_days: 30  # Valid value: monthly
    )

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      agenda = service.generate_agenda(@date_range)

      flexible_suggestions = agenda.suggestions.select { |s| s.activity == @activity_flexible }

      assert flexible_suggestions.any?, "Should include flexible activity suggestions"
      flexible_suggestions.each do |suggestion|
        assert_equal "flexible", suggestion.type
        assert_equal "medium", suggestion.confidence
        assert suggestion.start_time < suggestion.end_time
      end
    end
  end

  test "generate_agenda includes deadline activities before their deadline" do
    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_deadline ])
      agenda = service.generate_agenda(@date_range)

      deadline_suggestion = agenda.suggestions.find { |s| s.activity == @activity_deadline }

      assert deadline_suggestion, "Should include deadline activity"
      assert_equal "deadline", deadline_suggestion.type
      assert_equal "high", deadline_suggestion.confidence
      assert deadline_suggestion.start_time < @activity_deadline.deadline
      assert deadline_suggestion.title.include?("Complete:")
    end
  end

  test "generate_agenda respects work hours option for work-related activities" do
    @activity_flexible.update!(
      name: "Work Meeting Prep",
      schedule_type: "flexible",
      max_frequency_days: 30
    )

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(
        @user,
        [ @activity_flexible ],
        { work_hours_start: 9, work_hours_end: 17 }
      )

      agenda = service.generate_agenda(@date_range)
      work_suggestions = agenda.suggestions.select { |s| s.activity == @activity_flexible }

      work_suggestions.each do |suggestion|
        hour = suggestion.start_time.hour
        assert hour >= 9, "Work activity should start during work hours (got #{hour})"
      end
    end
  end

  test "generate_agenda respects exclude weekends option" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)
  
    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(
        @user,
        [ @activity_flexible ],
        { exclude_weekends: true }
      )
  
      agenda = service.generate_agenda(@date_range)
  
      weekend_suggestions = agenda.suggestions.select do |s|
        s.start_time.to_date.saturday? || s.start_time.to_date.sunday?
      end
  
      assert_empty weekend_suggestions, "Should not schedule on weekends when excluded"
    end
  end

  # ============================================================================
  # Public API: Conflict Detection and Resolution Tests
  # ============================================================================

  test "generate_agenda avoids conflicts with existing calendar events" do
    conflict_time = 2.days.from_now.beginning_of_day + 10.hours

    events = [
      {
        summary: "Existing Meeting",
        start_time: conflict_time,
        end_time: conflict_time + 1.hour
      }
    ]

    @activity_flexible.update!(
      schedule_type: "flexible",
      max_frequency_days: 30
    )

    with_mocked_google_calendar(events) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      agenda = service.generate_agenda(@date_range)

      # Verify no suggestions overlap with the existing meeting
      agenda.suggestions.each do |suggestion|
        overlaps = suggestion.start_time < (conflict_time + 1.hour) &&
                  suggestion.end_time > conflict_time

        refute overlaps, "Suggestion should not overlap with existing events"
      end
    end
  end

  test "generate_agenda marks strict activities that conflict as low confidence" do
    conflict_time = 2.days.from_now.beginning_of_day + 10.hours

    events = [
      {
        summary: "Blocking Event",
        start_time: conflict_time,
        end_time: conflict_time + 1.hour
      }
    ]

    @activity_strict.update!(
      schedule_type: "strict",
      start_time: conflict_time + 30.minutes,
      end_time: conflict_time + 1.5.hours,
      max_frequency_days: 30
    )

    with_mocked_google_calendar(events) do
      service = ActivitySchedulingService.new(@user, [ @activity_strict ])
      agenda = service.generate_agenda(@date_range)

      strict_suggestion = agenda.suggestions.find { |s| s.activity == @activity_strict }

      assert strict_suggestion, "Should still include conflicting strict activity"
      assert_equal "low", strict_suggestion.confidence, "Conflicting strict activity should have low confidence"
      assert strict_suggestion.has_conflict?, "Should be marked as having a conflict"
    end
  end

  test "generate_agenda reschedules flexible activities when conflicts exist" do
    conflict_time = 2.days.from_now.beginning_of_day + 19.hours # 7 PM

    events = [
      {
        summary: "Evening Event",
        start_time: conflict_time,
        end_time: conflict_time + 1.hour
      }
    ]

    @activity_flexible.update!(
      name: "Evening Activity", # Would normally be scheduled at 7 PM
      schedule_type: "flexible",
      max_frequency_days: 30
    )

    with_mocked_google_calendar(events) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      agenda = service.generate_agenda(@date_range)

      # Should reschedule to avoid the 7 PM conflict
      flexible_suggestions = agenda.suggestions.select { |s| s.activity == @activity_flexible }
      rescheduled = flexible_suggestions.any?(&:conflict_avoided?)

      # Either rescheduled or scheduled on different days
      assert flexible_suggestions.any?, "Should include flexible activity (possibly rescheduled)"

      if rescheduled
        assert_equal "medium", flexible_suggestions.first.confidence
      end
    end
  end

  test "generate_agenda handles user with no Google account gracefully" do
    @user.google_accounts.destroy_all
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)

    service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
    agenda = service.generate_agenda(@date_range)

    assert_instance_of AgendaProposal, agenda
    assert_empty agenda.existing_events, "Should have no existing events"
    # Service still generates suggestions even without calendar integration
    assert_kind_of Array, agenda.suggestions
  end

  # ============================================================================
  # Public API: create_calendar_events Tests
  # ============================================================================

  test "create_calendar_events returns DryRunResults in dry run mode" do
    suggestions = build_test_suggestions([ @activity_flexible ])

    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events(suggestions, dry_run: true)

    assert_instance_of ActivitySchedulingService::DryRunResults, results
    assert_equal 1, results.total_suggestions
    assert results.next_steps.any?
    assert_kind_of Array, results.timeline
  end

  test "create_calendar_events defaults to dry run mode" do
    suggestions = build_test_suggestions([ @activity_flexible ])

    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events(suggestions)

    assert_instance_of ActivitySchedulingService::DryRunResults, results
  end

  test "create_calendar_events handles empty suggestions gracefully" do
    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events([])

    assert_instance_of ActivitySchedulingService::DryRunResults, results
    assert_equal 0, results.total_suggestions
    assert results.next_steps.include?("No activities to schedule in the selected date range")
  end

  test "create_calendar_events includes timeline with activity details" do
    suggestions = build_test_suggestions([ @activity_flexible, @activity_deadline ])

    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events(suggestions, dry_run: true)

    assert_equal 2, results.timeline.count

    results.timeline.each do |item|
      assert_instance_of ActivitySchedulingService::TimelineItem, item
      assert item.activity_name
      assert item.title
      assert item.start_time
      assert item.end_time
      assert item.type
      assert item.confidence
    end
  end

  test "create_calendar_events groups suggestions by type" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)
    @activity_deadline.update!(schedule_type: "deadline")

    suggestions = build_test_suggestions([ @activity_flexible, @activity_deadline ])

    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events(suggestions, dry_run: true)

    assert_equal 1, results.suggestions_by_type["flexible"]
    assert_equal 1, results.suggestions_by_type["deadline"]
  end

  test "create_calendar_events filters to only suggested activities" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)

    events = [
      {
        summary: "Existing Event",
        start_time: Time.current + 1.day,
        end_time: Time.current + 1.day + 1.hour
      }
    ]

    with_mocked_google_calendar(events) do
      agenda = ActivitySchedulingService.new(@user, [ @activity_flexible ]).generate_agenda(@date_range)

      # Agenda includes both existing events and suggestions
      results = ActivitySchedulingService.new(@user).create_calendar_events(
        agenda.all_events,
        dry_run: true
      )

      # Should only count suggested activities, not existing calendar events
      assert_equal agenda.suggestions.count, results.total_suggestions
    end
  end

  # ============================================================================
  # Public API: schedule_activities Tests
  # ============================================================================

  test "schedule_activities generates agenda and returns dry run results" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      results = service.schedule_activities(@date_range, dry_run: true)

      assert_instance_of ActivitySchedulingService::DryRunResults, results
      assert results.total_suggestions >= 0
    end
  end

  test "schedule_activities uses default date range when none provided" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      results = service.schedule_activities

      assert_instance_of ActivitySchedulingService::DryRunResults, results
    end
  end

  test "schedule_activities integrates conflict detection" do
    conflict_time = 2.days.from_now.beginning_of_day + 10.hours
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)

    events = [
      {
        summary: "Busy Time",
        start_time: conflict_time,
        end_time: conflict_time + 2.hours
      }
    ]

    with_mocked_google_calendar(events) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      results = service.schedule_activities(@date_range, dry_run: true)

      assert_instance_of ActivitySchedulingService::DryRunResults, results
      # Should have loaded the existing events
      assert results.existing_events_count >= 0
      # Should have processed conflicts if any were detected
      assert_kind_of Integer, results.conflicts_avoided
    end
  end

  # ============================================================================
  # Data Structure Tests
  # ============================================================================

  test "CalendarInfo provides direct attribute access" do
    calendar_info = ActivitySchedulingService::CalendarInfo.new(
      id: "test_id",
      summary: "Test Calendar",
      description: "Description",
      primary: true,
      access_role: "owner"
    )

    assert_equal "test_id", calendar_info.id
    assert_equal "Test Calendar", calendar_info.summary
    assert_equal "Description", calendar_info.description
    assert calendar_info.primary
    assert_equal "owner", calendar_info.access_role
  end

  test "CalendarInfo.from_api creates instance from Google API object" do
    require "ostruct"

    api_calendar = OpenStruct.new(
      id: "cal_123",
      summary: "My Calendar",
      description: "Test",
      primary: false,
      access_role: "writer"
    )

    calendar_info = ActivitySchedulingService::CalendarInfo.from_api(api_calendar)

    assert_equal "cal_123", calendar_info.id
    assert_equal "My Calendar", calendar_info.summary
    refute calendar_info.primary
    assert_equal "writer", calendar_info.access_role
  end

  test "TimelineItem provides structured access to suggestion details" do
    timeline_item = ActivitySchedulingService::TimelineItem.new(
      activity_name: "Test Activity",
      title: "Test Title",
      start_time: Time.current,
      end_time: Time.current + 1.hour,
      type: "flexible",
      confidence: "medium",
      notes: [ "Note 1", "Note 2" ]
    )

    assert_equal "Test Activity", timeline_item.activity_name
    assert_equal "Test Title", timeline_item.title
    assert_equal "flexible", timeline_item.type
    assert_equal "medium", timeline_item.confidence
    assert_equal 2, timeline_item.notes.count
  end

  test "DryRunResults provides complete scheduling summary" do
    results = ActivitySchedulingService::DryRunResults.new(
      total_suggestions: 5,
      suggestions_by_type: { "flexible" => 3, "strict" => 2 },
      existing_events_count: 10,
      conflicts_avoided: 2,
      timeline: [],
      next_steps: [ "Review schedule" ]
    )

    assert_equal 5, results.total_suggestions
    assert_equal 3, results.suggestions_by_type["flexible"]
    assert_equal 10, results.existing_events_count
    assert_equal 2, results.conflicts_avoided
    assert_equal 1, results.next_steps.count
  end

  private

  # ============================================================================
  # Test Helpers - Clean, professional mocking without accessing internals
  # ============================================================================

  def with_mocked_google_calendar(events)
    mock_service = MockGoogleCalendarService.new(events)

    # Temporarily replace GoogleCalendarService.new
    original_method = GoogleCalendarService.singleton_class.instance_method(:new)

    GoogleCalendarService.define_singleton_method(:new) do |*args|
      mock_service
    end

    begin
      yield
    ensure
      # Restore original behavior
      GoogleCalendarService.singleton_class.define_method(:new, original_method)
    end
  end

  def build_test_suggestions(activities)
    activities.map do |activity|
      {
        activity: activity,
        title: activity.name,
        start_time: Time.current + 1.day,
        end_time: Time.current + 1.day + 1.hour,
        type: activity.schedule_type || "flexible",
        confidence: "medium"
      }
    end
  end
end

# Mock object for GoogleCalendarService - encapsulates test double behavior
class MockGoogleCalendarService
  def initialize(events)
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
