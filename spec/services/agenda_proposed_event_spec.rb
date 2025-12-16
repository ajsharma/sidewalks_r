require "rails_helper"

RSpec.describe AgendaProposedEvent, type: :service do
  before do
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
  it "initializes with calendar event data" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    expect(event.raw_data).to eq @calendar_data
    expect(event.user_timezone).to eq @user_timezone
    expect(event.source).to eq "calendar"
  end

  it "initializes with suggestion data" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")

    expect(event.raw_data).to eq @suggestion_data
    expect(event.user_timezone).to eq @user_timezone
    expect(event.source).to eq "suggestion"
  end

  # Title tests
  it "returns calendar summary as title for calendar events" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    expect(event.title).to eq "Meeting with Team"
  end

  it "returns 'Busy' as title for calendar events without summary" do
    data = @calendar_data.dup
    data.delete(:summary)
    event = described_class.new(data, user_timezone: @user_timezone, source: "calendar")
    expect(event.title).to eq "Busy"
  end

  it "returns suggestion title for activity suggestions" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    expect(event.title).to eq "Go for a Run"
  end

  # Time tests
  it "normalizes start time to user timezone" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    start_time = event.start_time
    expect(start_time).to eq @base_time.in_time_zone(@user_timezone)
  end

  it "normalizes end time to user timezone" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    end_time = event.end_time
    expect(end_time).to eq (@base_time + 1.hour).in_time_zone(@user_timezone)
  end

  it "handles nil start time" do
    data = @calendar_data.dup
    data[:start_time] = nil
    event = described_class.new(data, user_timezone: @user_timezone, source: "calendar")

    expect(event.start_time).to be_nil
  end

  it "handles nil end time" do
    data = @calendar_data.dup
    data[:end_time] = nil
    event = described_class.new(data, user_timezone: @user_timezone, source: "calendar")

    expect(event.end_time).to be_nil
  end

  it "caches normalized times" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    # Call twice to test caching
    time1 = event.start_time
    time2 = event.start_time

    expect(time1).to eq time2
    expect(time1).to be time2  # Should be the same object instance
  end

  # Duration test
  it "calculates duration correctly" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    expect(event.duration).to eq 1.hour
  end

  # Type tests
  it "returns 'existing' type for calendar events" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    expect(event.type).to eq "existing"
  end

  it "returns suggestion type for activity suggestions" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    expect(event.type).to eq "exercise"
  end

  # Calendar-specific attribute tests
  it "returns calendar name for calendar events" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    expect(event.calendar_name).to eq "Work Calendar"
  end

  it "returns nil calendar name for suggestions" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    expect(event.calendar_name).to be_nil
  end

  it "returns calendar id for calendar events" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    expect(event.calendar_id).to eq "work@example.com"
  end

  it "returns nil calendar id for suggestions" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    expect(event.calendar_id).to be_nil
  end

  # Activity suggestion-specific attribute tests
  it "returns confidence for suggestions" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    expect(event.confidence).to eq 0.85
  end

  it "returns nil confidence for calendar events" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    expect(event.confidence).to be_nil
  end

  it "returns urgency for suggestions" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    expect(event.urgency).to eq "medium"
  end

  it "returns nil urgency for calendar events" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    expect(event.urgency).to be_nil
  end

  it "returns frequency note for suggestions" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    expect(event.frequency_note).to eq "3x per week"
  end

  it "returns nil frequency note for calendar events" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    expect(event.frequency_note).to be_nil
  end

  it "returns activity for suggestions" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    expect(event.activity).to eq activities(:one)
  end

  it "returns nil activity for calendar events" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")
    expect(event.activity).to be_nil
  end

  # Conflict detection tests
  it "detects conflicts when has_conflict is true" do
    data = @suggestion_data.dup
    data[:has_conflict] = true
    event = described_class.new(data, user_timezone: @user_timezone, source: "suggestion")

    expect(event.has_conflict?).to be true
  end

  it "does not detect conflicts when has_conflict is false" do
    data = @suggestion_data.dup
    data[:has_conflict] = false
    event = described_class.new(data, user_timezone: @user_timezone, source: "suggestion")

    expect(event.has_conflict?).to be false
  end

  it "does not detect conflicts when has_conflict is nil" do
    data = @suggestion_data.dup
    data.delete(:has_conflict)
    event = described_class.new(data, user_timezone: @user_timezone, source: "suggestion")

    expect(event.has_conflict?).to be false
  end

  it "detects conflict avoided when conflict_avoided is true" do
    data = @suggestion_data.dup
    data[:conflict_avoided] = true
    event = described_class.new(data, user_timezone: @user_timezone, source: "suggestion")

    expect(event.conflict_avoided?).to be true
  end

  it "does not detect conflict avoided when conflict_avoided is false" do
    data = @suggestion_data.dup
    data[:conflict_avoided] = false
    event = described_class.new(data, user_timezone: @user_timezone, source: "suggestion")

    expect(event.conflict_avoided?).to be false
  end

  # Notes tests
  it "returns notes array" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")
    expect(event.notes).to eq [ "Good weather today", "Track available" ]
  end

  it "returns empty array when notes is nil" do
    data = @suggestion_data.dup
    data.delete(:notes)
    event = described_class.new(data, user_timezone: @user_timezone, source: "suggestion")

    expect(event.notes).to eq []
  end

  # Source detection tests
  it "identifies existing calendar events" do
    event = described_class.new(@calendar_data, user_timezone: @user_timezone, source: "calendar")

    expect(event.existing_event?).to be true
    expect(event.suggested_activity?).to be false
  end

  it "identifies suggested activities" do
    event = described_class.new(@suggestion_data, user_timezone: @user_timezone, source: "suggestion")

    expect(event.suggested_activity?).to be true
    expect(event.existing_event?).to be false
  end
end
