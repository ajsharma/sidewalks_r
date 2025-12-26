require "test_helper"
require "ostruct"

class ActivitySchedulingServiceTest < ActiveSupport::TestCase
  include GoogleHelpers::GoogleCalendarMockHelper

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

  test "generate_agenda does not schedule events in the past" do
    @activity_flexible.update!(
      name: "Morning Walk",
      schedule_type: "flexible",
      max_frequency_days: 1
    )

    with_mocked_google_calendar([]) do
      # Simulate it being 9:18 AM
      travel_to Time.zone.parse("2025-10-26 09:18:00") do
        service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
        date_range = Date.current..(Date.current + 1.day)
        agenda = service.generate_agenda(date_range)

        # Get the minimum allowed start time (current + 1 hour, rounded to nearest half-hour)
        # 9:18 AM + 1 hour = 10:18 AM, rounded up = 10:30 AM
        min_time = service.send(:minimum_start_time)
        current_time = Time.current

        # Verify minimum time calculation
        assert min_time > current_time, "Minimum time should be after current time"
        assert_equal 30, min_time.min, "Minimum time should be rounded to :30"

        # Verify all suggestions are scheduled at or after minimum time
        today_suggestions = agenda.suggestions.select { |s| s.start_time.to_date == Date.current }
        assert today_suggestions.any?, "Should have suggestions for today"

        today_suggestions.each do |suggestion|
          assert suggestion.start_time >= min_time,
            "Suggestion #{suggestion.title} at #{suggestion.start_time} should not be before minimum time #{min_time}"
        end
      end
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

  test "generate_agenda staggers multiple flexible activities on the same day" do
    # Create multiple flexible activities that would be scheduled on the same day
    # Use generic names to ensure they all get the same base time slot
    activity1 = Activity.create!(
      user: @user,
      name: "Activity A",
      schedule_type: "flexible",
      max_frequency_days: 1  # Daily
    )

    activity2 = Activity.create!(
      user: @user,
      name: "Activity B",
      schedule_type: "flexible",
      max_frequency_days: 1  # Daily
    )

    activity3 = Activity.create!(
      user: @user,
      name: "Activity C",
      schedule_type: "flexible",
      max_frequency_days: 1  # Daily
    )

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ activity1, activity2, activity3 ])
      agenda = service.generate_agenda(@date_range)

      # Get suggestions for the first day only
      first_day = agenda.suggestions.first.start_time.to_date
      same_day_suggestions = agenda.suggestions.select { |s| s.start_time.to_date == first_day }

      # Verify we have multiple activities on the same day
      assert same_day_suggestions.count >= 2, "Should have multiple activities on the same day"

      # Verify they have different start times (staggered)
      start_times = same_day_suggestions.map(&:start_time).uniq
      assert_equal same_day_suggestions.count, start_times.count,
        "All activities on the same day should have different start times"

      # Verify activities don't overlap with each other
      same_day_suggestions.combination(2).each do |s1, s2|
        overlaps = s1.start_time < s2.end_time && s1.end_time > s2.start_time
        refute overlaps, "Activities #{s1.title} and #{s2.title} should not overlap"
      end
    end
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
        summary: "Evening Event 1",
        start_time: conflict_time,
        end_time: conflict_time + 1.hour
      },
      {
        summary: "Evening Event 2",
        start_time: conflict_time + 1.hour,
        end_time: conflict_time + 2.hours
      }
    ]

    # Create multiple flexible activities that would prefer evening slots
    activity1 = Activity.create!(
      user: @user,
      name: "Evening Activity 1",
      schedule_type: "flexible",
      max_frequency_days: 1  # Daily
    )

    activity2 = Activity.create!(
      user: @user,
      name: "Evening Activity 2",
      schedule_type: "flexible",
      max_frequency_days: 1  # Daily
    )

    activity3 = Activity.create!(
      user: @user,
      name: "Evening Activity 3",
      schedule_type: "flexible",
      max_frequency_days: 1  # Daily
    )

    with_mocked_google_calendar(events) do
      service = ActivitySchedulingService.new(@user, [ activity1, activity2, activity3 ])
      agenda = service.generate_agenda(@date_range)

      # Get suggestions for the conflict day
      conflict_day = conflict_time.to_date
      conflict_day_suggestions = agenda.suggestions.select { |s| s.start_time.to_date == conflict_day }

      # Should have suggestions (possibly rescheduled)
      assert conflict_day_suggestions.any?, "Should have suggestions for the conflict day"

      # Verify no suggestions overlap with existing events
      conflict_day_suggestions.each do |suggestion|
        events.each do |event|
          overlaps = suggestion.start_time < event[:end_time] &&
                    suggestion.end_time > event[:start_time]
          refute overlaps, "#{suggestion.title} should not overlap with #{event[:summary]}"
        end
      end

      # Verify rescheduled activities don't overlap with each other
      conflict_day_suggestions.combination(2).each do |s1, s2|
        overlaps = s1.start_time < s2.end_time && s1.end_time > s2.start_time
        refute overlaps,
          "Rescheduled activities #{s1.title} and #{s2.title} should not overlap with each other"
      end
    end
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
  # Test Helpers
  # ============================================================================
  # Note: with_mocked_google_calendar is provided by GoogleHelpers::GoogleCalendarMockHelper
  # in test/support/google_helpers/google_calendar_mock_helper.rb

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
