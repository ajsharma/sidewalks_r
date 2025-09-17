require "test_helper"

class AgendaProposedEventTest < ActiveSupport::TestCase
  setup do
    @user_timezone = "Pacific Time (US & Canada)"
    @base_time = Time.zone.parse("2024-01-15 10:00:00")

    # Calendar event data
    @calendar_data = {
      summary: "Meeting with Team",
      start_time: @base_time,
      end_time: @base_time + 1.hour,
      calendar_name: "Work Calendar",
      calendar_id: "work@example.com"
    }

    # Activity suggestion data
    @suggestion_data = {
      title: "Go for a Run",
      start_time: @base_time + 2.hours,
      end_time: @base_time + 3.hours,
      type: "exercise",
      confidence: 0.85,
      urgency: "medium",
      frequency_note: "3x per week",
      has_conflict: false,
      conflict_avoided: true,
      notes: [ "Good weather today", "Track available" ],
      activity: activities(:one)
    }
  end

  # Initialization tests
  test "should initialize with calendar event data" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    assert_equal @calendar_data, event.raw_data
    assert_equal @user_timezone, event.user_timezone
    assert_equal "calendar", event.source
  end

  test "should initialize with suggestion data" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")

    assert_equal @suggestion_data, event.raw_data
    assert_equal @user_timezone, event.user_timezone
    assert_equal "suggestion", event.source
  end

  # Title tests
  test "should return calendar summary as title for calendar events" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    assert_equal "Meeting with Team", event.title
  end

  test "should return 'Busy' as title for calendar events without summary" do
    data = @calendar_data.dup
    data.delete(:summary)
    event = AgendaProposedEvent.new(data, user_timezone: @user_timezone, source: "calendar")
    assert_equal "Busy", event.title
  end

  test "should return suggestion title for activity suggestions" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    assert_equal "Go for a Run", event.title
  end

  # Time tests
  test "should normalize start time to user timezone" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    start_time = event.start_time
    assert_equal @base_time.in_time_zone(@user_timezone), start_time
  end

  test "should normalize end time to user timezone" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    end_time = event.end_time
    assert_equal (@base_time + 1.hour).in_time_zone(@user_timezone), end_time
  end

  test "should handle nil start time" do
    data = @calendar_data.dup
    data[:start_time] = nil
    event = AgendaProposedEvent.new(data, user_timezone: @user_timezone, source: "calendar")

    assert_nil event.start_time
  end

  test "should handle nil end time" do
    data = @calendar_data.dup
    data[:end_time] = nil
    event = AgendaProposedEvent.new(data, user_timezone: @user_timezone, source: "calendar")

    assert_nil event.end_time
  end

  test "should cache normalized times" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    # Call twice to test caching
    time1 = event.start_time
    time2 = event.start_time

    assert_equal time1, time2
    assert_same time1, time2  # Should be the same object instance
  end

  # Duration test
  test "should calculate duration correctly" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    assert_equal 1.hour, event.duration
  end

  # Type tests
  test "should return 'existing' type for calendar events" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    assert_equal "existing", event.type
  end

  test "should return suggestion type for activity suggestions" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    assert_equal "exercise", event.type
  end

  # Calendar-specific attribute tests
  test "should return calendar name for calendar events" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    assert_equal "Work Calendar", event.calendar_name
  end

  test "should return nil calendar name for suggestions" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    assert_nil event.calendar_name
  end

  test "should return calendar id for calendar events" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    assert_equal "work@example.com", event.calendar_id
  end

  test "should return nil calendar id for suggestions" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    assert_nil event.calendar_id
  end

  # Activity suggestion-specific attribute tests
  test "should return confidence for suggestions" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    assert_equal 0.85, event.confidence
  end

  test "should return nil confidence for calendar events" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    assert_nil event.confidence
  end

  test "should return urgency for suggestions" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    assert_equal "medium", event.urgency
  end

  test "should return nil urgency for calendar events" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    assert_nil event.urgency
  end

  test "should return frequency note for suggestions" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    assert_equal "3x per week", event.frequency_note
  end

  test "should return nil frequency note for calendar events" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    assert_nil event.frequency_note
  end

  test "should return activity for suggestions" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    assert_equal activities(:one), event.activity
  end

  test "should return nil activity for calendar events" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    assert_nil event.activity
  end

  # Conflict detection tests
  test "should detect conflicts when has_conflict is true" do
    data = @suggestion_data.dup
    data[:has_conflict] = true
    event = AgendaProposedEvent.new(data, user_timezone: @user_timezone, source: "suggestion")

    assert event.has_conflict?
  end

  test "should not detect conflicts when has_conflict is false" do
    data = @suggestion_data.dup
    data[:has_conflict] = false
    event = AgendaProposedEvent.new(data, user_timezone: @user_timezone, source: "suggestion")

    assert_not event.has_conflict?
  end

  test "should not detect conflicts when has_conflict is nil" do
    data = @suggestion_data.dup
    data.delete(:has_conflict)
    event = AgendaProposedEvent.new(data, user_timezone: @user_timezone, source: "suggestion")

    assert_not event.has_conflict?
  end

  test "should detect conflict avoided when conflict_avoided is true" do
    data = @suggestion_data.dup
    data[:conflict_avoided] = true
    event = AgendaProposedEvent.new(data, user_timezone: @user_timezone, source: "suggestion")

    assert event.conflict_avoided?
  end

  test "should not detect conflict avoided when conflict_avoided is false" do
    data = @suggestion_data.dup
    data[:conflict_avoided] = false
    event = AgendaProposedEvent.new(data, user_timezone: @user_timezone, source: "suggestion")

    assert_not event.conflict_avoided?
  end

  # Notes tests
  test "should return notes array" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    assert_equal [ "Good weather today", "Track available" ], event.notes
  end

  test "should return empty array when notes is nil" do
    data = @suggestion_data.dup
    data.delete(:notes)
    event = AgendaProposedEvent.new(data, user_timezone: @user_timezone, source: "suggestion")

    assert_equal [], event.notes
  end

  # Source detection tests
  test "should identify existing calendar events" do
    event = AgendaProposedEvent.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    assert event.existing_event?
    assert_not event.suggested_activity?
  end

  test "should identify suggested activities" do
    event = AgendaProposedEvent.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")

    assert event.suggested_activity?
    assert_not event.existing_event?
  end
end
