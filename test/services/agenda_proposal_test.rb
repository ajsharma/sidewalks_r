require "test_helper"

class AgendaProposalTest < ActiveSupport::TestCase
  setup do
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

    @agenda_proposal = AgendaProposal.new(
      existing_events: @existing_events,
      suggestions: @suggestions,
      date_range: @date_range,
      user_timezone: @user_timezone
    )
  end

  test "initializes with correct attributes" do
    assert_equal @existing_events, @agenda_proposal.raw_existing_events
    assert_equal @suggestions, @agenda_proposal.raw_suggestions
    assert_equal @date_range, @agenda_proposal.date_range
    assert_equal @user_timezone, @agenda_proposal.user_timezone
  end

  test "existing_events returns normalized events" do
    events = @agenda_proposal.existing_events
    assert_equal 1, events.size
    assert_instance_of AgendaProposedEvent, events.first
    assert_equal "calendar", events.first.source
  end

  test "suggestions returns normalized suggestions" do
    suggestions = @agenda_proposal.suggestions
    assert_equal 1, suggestions.size
    assert_instance_of AgendaProposedEvent, suggestions.first
    assert_equal "suggestion", suggestions.first.source
  end

  test "all_events combines and sorts events" do
    all_events = @agenda_proposal.all_events
    assert_equal 2, all_events.size
    assert all_events.first.start_time <= all_events.last.start_time
  end

  test "events_by_date groups events by date" do
    events_by_date = @agenda_proposal.events_by_date
    assert_instance_of Hash, events_by_date

    # Both events should be on the same date
    assert_equal 1, events_by_date.keys.size
    date = events_by_date.keys.first
    assert_equal 2, events_by_date[date].size
  end

  test "summary returns agenda summary" do
    summary = @agenda_proposal.summary
    assert_instance_of ActivitySchedulingService::AgendaSummary, summary
    assert_equal 1, summary.total_suggestions
    assert_equal 1, summary.total_existing
    assert_equal 2, summary.total_events
    assert_equal @date_range.begin, summary.date_range_start
    assert_equal @date_range.end, summary.date_range_end
  end

  test "any_events? returns true when events exist" do
    assert @agenda_proposal.any_events?
  end

  test "any_events? returns false when no events exist" do
    empty_proposal = AgendaProposal.new(
      existing_events: [],
      suggestions: [],
      date_range: @date_range,
      user_timezone: @user_timezone
    )
    assert_not empty_proposal.any_events?
  end

  test "google_calendar_connected? returns true when existing events present" do
    assert @agenda_proposal.google_calendar_connected?
  end

  test "google_calendar_connected? returns false when no calendar indicators" do
    proposal_without_calendar = AgendaProposal.new(
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
    assert_not proposal_without_calendar.google_calendar_connected?
  end
end
