require "rails_helper"

RSpec.describe AgendaProposal, type: :service do
  before do
    @user_timezone = "America/Los_Angeles"
    @date_range = Date.current..Date.current + 7.days
    @existing_events = [
      {
        summary: "Existing Meeting",
        start_time: "2024-01-01T10:00:00-08:00",
        end_time: "2024-01-01T11:00:00-08:00"
      }
    ]
    @suggestions = [
      {
        title: "Suggested Activity",
        start_time: "2024-01-01T14:00:00-08:00",
        end_time: "2024-01-01T15:00:00-08:00",
        activity: { name: "Test Activity", schedule_type: "flexible" }
      }
    ]

    @agenda_proposal = described_class.new(
      existing_events: @existing_events,
      suggestions: @suggestions,
      date_range: @date_range,
      user_timezone: @user_timezone
    )
  end

  it "initializes with correct attributes" do
    expect(@agenda_proposal.raw_existing_events).to eq @existing_events
    expect(@agenda_proposal.raw_suggestions).to eq @suggestions
    expect(@agenda_proposal.date_range).to eq @date_range
    expect(@agenda_proposal.user_timezone).to eq @user_timezone
  end

  it "existing_events returns normalized events" do
    events = @agenda_proposal.existing_events
    expect(events.size).to eq 1
    expect(events.first).to be_a AgendaProposedEvent
    expect(events.first.source).to eq "calendar"
  end

  it "suggestions returns normalized suggestions" do
    suggestions = @agenda_proposal.suggestions
    expect(suggestions.size).to eq 1
    expect(suggestions.first).to be_a AgendaProposedEvent
    expect(suggestions.first.source).to eq "suggestion"
  end

  it "all_events combines and sorts events" do
    all_events = @agenda_proposal.all_events
    expect(all_events.size).to eq 2
    expect(all_events.first.start_time).to be <= all_events.last.start_time
  end

  it "events_by_date groups events by date" do
    events_by_date = @agenda_proposal.events_by_date
    expect(events_by_date).to be_a Hash

    # Both events should be on the same date
    expect(events_by_date.keys.size).to eq 1
    date = events_by_date.keys.first
    expect(events_by_date[date].size).to eq 2
  end

  it "summary returns agenda summary" do
    summary = @agenda_proposal.summary
    expect(summary).to be_a ActivitySchedulingService::AgendaSummary
    expect(summary.total_suggestions).to eq 1
    expect(summary.total_existing).to eq 1
    expect(summary.total_events).to eq 2
    expect(summary.date_range_start).to eq @date_range.begin
    expect(summary.date_range_end).to eq @date_range.end
  end

  it "any_events? returns true when events exist" do
    expect(@agenda_proposal.any_events?).to be true
  end

  it "any_events? returns false when no events exist" do
    empty_proposal = described_class.new(
      existing_events: [],
      suggestions: [],
      date_range: @date_range,
      user_timezone: @user_timezone
    )
    expect(empty_proposal.any_events?).to be false
  end

  it "google_calendar_connected? returns true when existing events present" do
    expect(@agenda_proposal.google_calendar_connected?).to be true
  end

  it "google_calendar_connected? returns false when no calendar indicators" do
    proposal_without_calendar = described_class.new(
      existing_events: [],
      suggestions: [
        {
          title: "Suggested Activity",
          start_time: "2024-01-01T14:00:00-08:00",
          end_time: "2024-01-01T15:00:00-08:00",
          activity: { name: "Test Activity", schedule_type: "flexible" }
        }
      ],
      date_range: @date_range,
      user_timezone: @user_timezone
    )
    expect(proposal_without_calendar.google_calendar_connected?).to be false
  end
end
