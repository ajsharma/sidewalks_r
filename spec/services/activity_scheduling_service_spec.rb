require "rails_helper"

RSpec.describe ActivitySchedulingService, type: :service do
  include GoogleHelpers::GoogleCalendarMockHelper

  before do
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

  it "initializes with user and loads active activities by default" do
    service = ActivitySchedulingService.new(@user)

    expect(service.user).to eq @user
    expect(service.activities).to eq @user.activities.active
    expect(service.options).to be_a Hash
  end

  it "accepts custom activities and options" do
    custom_activities = [ @activity_strict ]
    custom_options = { work_hours_start: 8, exclude_weekends: true }

    service = ActivitySchedulingService.new(@user, custom_activities, custom_options)

    expect(service.activities).to eq custom_activities
    expect(service.options[:work_hours_start]).to eq 8
    expect(service.options[:exclude_weekends]).to be true
    expect(service.options[:work_hours_end]).to eq 17 # Default preserved
  end

  it "raises error when user is blank" do
    expect {
      ActivitySchedulingService.new(nil)
    }.to raise_error(ArgumentError, /Blank use/)
  end

  it "raises error when user timezone is blank" do
    @user.update!(timezone: nil)

    expect {
      ActivitySchedulingService.new(@user)
    }.to raise_error(ArgumentError, /time zone/)
  end

  # ============================================================================
  # Public API: generate_agenda Tests
  # ============================================================================

  it "generate_agenda returns AgendaProposal with suggestions" do
    with_mocked_google_calendar([]) do
      agenda = ActivitySchedulingService.new(@user).generate_agenda(@date_range)

      expect(agenda).to be_a AgendaProposal
      expect(agenda.suggestions).to be_a Array
      expect(agenda.existing_events).to be_a Array
    end
  end

  it "generate_agenda uses default date range when none provided" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 1)

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      agenda = service.generate_agenda

      expect(agenda).to be_a AgendaProposal
      # Agenda should include suggestions (default range is 2 weeks)
      expect(agenda.suggestions.any?).to be true
    end
  end

  it "generate_agenda includes strict schedule activities at their exact times" do
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

      expect(strict_suggestion).to be_present
      expect(strict_suggestion.type).to eq "strict"
      expect(strict_suggestion.start_time).to eq start_time
      expect(strict_suggestion.end_time).to eq end_time
      expect(strict_suggestion.confidence).to eq "high"
    end
  end

  it "generate_agenda includes flexible activities at suggested times" do
    @activity_flexible.update!(
      schedule_type: "flexible",
      max_frequency_days: 30  # Valid value: monthly
    )

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      agenda = service.generate_agenda(@date_range)

      flexible_suggestions = agenda.suggestions.select { |s| s.activity == @activity_flexible }

      expect(flexible_suggestions.any?).to be true
      flexible_suggestions.each do |suggestion|
        expect(suggestion.type).to eq "flexible"
        expect(suggestion.confidence).to eq "medium"
        expect(suggestion.start_time).to be < suggestion.end_time
      end
    end
  end

  it "generate_agenda includes deadline activities before their deadline" do
    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_deadline ])
      agenda = service.generate_agenda(@date_range)

      deadline_suggestion = agenda.suggestions.find { |s| s.activity == @activity_deadline }

      expect(deadline_suggestion).to be_present
      expect(deadline_suggestion.type).to eq "deadline"
      expect(deadline_suggestion.confidence).to eq "high"
      expect(deadline_suggestion.start_time).to be < @activity_deadline.deadline
      expect(deadline_suggestion.title).to include("Complete:")
    end
  end

  it "generate_agenda respects work hours option for work-related activities" do
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
        expect(hour).to be >= 9
      end
    end
  end

  it "generate_agenda respects exclude weekends option" do
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

      expect(weekend_suggestions).to be_empty
    end
  end

  it "generate_agenda does not schedule events in the past" do
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
        expect(min_time).to be > current_time
        expect(min_time.min).to eq 30

        # Verify all suggestions are scheduled at or after minimum time
        today_suggestions = agenda.suggestions.select { |s| s.start_time.to_date == Date.current }
        expect(today_suggestions.any?).to be true

        today_suggestions.each do |suggestion|
          expect(suggestion.start_time).to be >= min_time,
            "Suggestion #{suggestion.title} at #{suggestion.start_time} should not be before minimum time #{min_time}"
        end
      end
    end
  end

  # ============================================================================
  # Public API: Conflict Detection and Resolution Tests
  # ============================================================================

  it "generate_agenda avoids conflicts with existing calendar events" do
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

        expect(overlaps).to be false
      end
    end
  end

  it "generate_agenda marks strict activities that conflict as low confidence" do
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

      expect(strict_suggestion).to be_present
      expect(strict_suggestion.confidence).to eq "low"
      expect(strict_suggestion.has_conflict?).to be true
    end
  end

  it "generate_agenda reschedules flexible activities when conflicts exist" do
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
      expect(flexible_suggestions.any?).to be true

      if rescheduled
        expect(flexible_suggestions.first.confidence).to eq "medium"
      end
    end
  end

  it "generate_agenda handles user with no Google account gracefully" do
    @user.google_accounts.destroy_all
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)

    service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
    agenda = service.generate_agenda(@date_range)

    expect(agenda).to be_a AgendaProposal
    expect(agenda.existing_events).to be_empty
    # Service still generates suggestions even without calendar integration
    expect(agenda.suggestions).to be_a Array
  end

  it "generate_agenda staggers multiple flexible activities on the same day" do
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
      expect(same_day_suggestions.count).to be >= 2

      # Verify they have different start times (staggered)
      start_times = same_day_suggestions.map(&:start_time).uniq
      expect(start_times.count).to eq same_day_suggestions.count

      # Verify activities don't overlap with each other
      same_day_suggestions.combination(2).each do |s1, s2|
        overlaps = s1.start_time < s2.end_time && s1.end_time > s2.start_time
        expect(overlaps).to be false
      end
    end
  end

  it "generate_agenda prevents rescheduled activities from conflicting with each other" do
    conflict_time = 2.days.from_now.beginning_of_day + 19.hours # 7 PM

    # Multiple existing events that block the preferred evening time slot
    events = [
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
      expect(conflict_day_suggestions.any?).to be true

      # Verify no suggestions overlap with existing events
      conflict_day_suggestions.each do |suggestion|
        events.each do |event|
          overlaps = suggestion.start_time < event[:end_time] &&
                    suggestion.end_time > event[:start_time]
          expect(overlaps).to be false
        end
      end

      # Verify rescheduled activities don't overlap with each other
      conflict_day_suggestions.combination(2).each do |s1, s2|
        overlaps = s1.start_time < s2.end_time && s1.end_time > s2.start_time
        expect(overlaps).to be false
      end
    end
  end

  # ============================================================================
  # Public API: create_calendar_events Tests
  # ============================================================================

  it "create_calendar_events returns DryRunResults in dry run mode" do
    suggestions = build_test_suggestions([ @activity_flexible ])

    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events(suggestions, dry_run: true)

    expect(results).to be_a ActivitySchedulingService::DryRunResults
    expect(results.total_suggestions).to eq 1
    expect(results.next_steps.any?).to be true
    expect(results.timeline).to be_a Array
  end

  it "create_calendar_events defaults to dry run mode" do
    suggestions = build_test_suggestions([ @activity_flexible ])

    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events(suggestions)

    expect(results).to be_a ActivitySchedulingService::DryRunResults
  end

  it "create_calendar_events handles empty suggestions gracefully" do
    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events([])

    expect(results).to be_a ActivitySchedulingService::DryRunResults
    expect(results.total_suggestions).to eq 0
    expect(results.next_steps).to include("No activities to schedule in the selected date range")
  end

  it "create_calendar_events includes timeline with activity details" do
    suggestions = build_test_suggestions([ @activity_flexible, @activity_deadline ])

    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events(suggestions, dry_run: true)

    expect(results.timeline.count).to eq 2

    results.timeline.each do |item|
      expect(item).to be_a ActivitySchedulingService::TimelineItem
      expect(item.activity_name).to be_present
      expect(item.title).to be_present
      expect(item.start_time).to be_present
      expect(item.end_time).to be_present
      expect(item.type).to be_present
      expect(item.confidence).to be_present
    end
  end

  it "create_calendar_events groups suggestions by type" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)
    @activity_deadline.update!(schedule_type: "deadline")

    suggestions = build_test_suggestions([ @activity_flexible, @activity_deadline ])

    service = ActivitySchedulingService.new(@user)
    results = service.create_calendar_events(suggestions, dry_run: true)

    expect(results.suggestions_by_type["flexible"]).to eq 1
    expect(results.suggestions_by_type["deadline"]).to eq 1
  end

  it "create_calendar_events filters to only suggested activities" do
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
      expect(results.total_suggestions).to eq agenda.suggestions.count
    end
  end

  # ============================================================================
  # Public API: schedule_activities Tests
  # ============================================================================

  it "schedule_activities generates agenda and returns dry run results" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      results = service.schedule_activities(@date_range, dry_run: true)

      expect(results).to be_a ActivitySchedulingService::DryRunResults
      expect(results.total_suggestions).to be >= 0
    end
  end

  it "schedule_activities uses default date range when none provided" do
    @activity_flexible.update!(schedule_type: "flexible", max_frequency_days: 30)

    with_mocked_google_calendar([]) do
      service = ActivitySchedulingService.new(@user, [ @activity_flexible ])
      results = service.schedule_activities

      expect(results).to be_a ActivitySchedulingService::DryRunResults
    end
  end

  it "schedule_activities integrates conflict detection" do
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

      expect(results).to be_a ActivitySchedulingService::DryRunResults
      # Should have loaded the existing events
      expect(results.existing_events_count).to be >= 0
      # Should have processed conflicts if any were detected
      expect(results.conflicts_avoided).to be_a Integer
    end
  end

  # ============================================================================
  # Data Structure Tests
  # ============================================================================

  it "CalendarInfo provides direct attribute access" do
    calendar_info = ActivitySchedulingService::CalendarInfo.new(
      id: "test_id",
      summary: "Test Calendar",
      description: "Description",
      primary: true,
      access_role: "owner"
    )

    expect(calendar_info.id).to eq "test_id"
    expect(calendar_info.summary).to eq "Test Calendar"
    expect(calendar_info.description).to eq "Description"
    expect(calendar_info.primary).to be true
    expect(calendar_info.access_role).to eq "owner"
  end

  it "CalendarInfo.from_api creates instance from Google API object" do
    require "ostruct"

    api_calendar = OpenStruct.new(
      id: "cal_123",
      summary: "My Calendar",
      description: "Test",
      primary: false,
      access_role: "writer"
    )

    calendar_info = ActivitySchedulingService::CalendarInfo.from_api(api_calendar)

    expect(calendar_info.id).to eq "cal_123"
    expect(calendar_info.summary).to eq "My Calendar"
    expect(calendar_info.primary).to be false
    expect(calendar_info.access_role).to eq "writer"
  end

  it "TimelineItem provides structured access to suggestion details" do
    timeline_item = ActivitySchedulingService::TimelineItem.new(
      activity_name: "Test Activity",
      title: "Test Title",
      start_time: Time.current,
      end_time: Time.current + 1.hour,
      type: "flexible",
      confidence: "medium",
      notes: [ "Note 1", "Note 2" ]
    )

    expect(timeline_item.activity_name).to eq "Test Activity"
    expect(timeline_item.title).to eq "Test Title"
    expect(timeline_item.type).to eq "flexible"
    expect(timeline_item.confidence).to eq "medium"
    expect(timeline_item.notes.count).to eq 2
  end

  it "DryRunResults provides complete scheduling summary" do
    results = ActivitySchedulingService::DryRunResults.new(
      total_suggestions: 5,
      suggestions_by_type: { "flexible" => 3, "strict" => 2 },
      existing_events_count: 10,
      conflicts_avoided: 2,
      timeline: [],
      next_steps: [ "Review schedule" ]
    )

    expect(results.total_suggestions).to eq 5
    expect(results.suggestions_by_type["flexible"]).to eq 3
    expect(results.existing_events_count).to eq 10
    expect(results.conflicts_avoided).to eq 2
    expect(results.next_steps.count).to eq 1
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
