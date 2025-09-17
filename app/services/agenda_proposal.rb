class AgendaProposal
  attr_reader :raw_existing_events, :raw_suggestions, :date_range, :user_timezone

  def initialize(existing_events:, suggestions:, date_range:, user_timezone:)
    @raw_existing_events = existing_events
    @raw_suggestions = suggestions
    @date_range = date_range
    @user_timezone = user_timezone
  end

  # Get normalized existing events
  def existing_events
    @existing_events ||= raw_existing_events.map do |event|
      AgendaProposedEvent.new(event, user_timezone: user_timezone, source: "calendar")
    end
  end

  # Get normalized suggestions
  def suggestions
    @suggestions ||= raw_suggestions.map do |suggestion|
      AgendaProposedEvent.new(suggestion, user_timezone: user_timezone, source: "suggestion")
    end
  end

  # Get all events (existing + suggestions) in chronological order
  def all_events
    @all_events ||= (existing_events + suggestions).sort_by(&:start_time)
  end

  # Get events grouped by date (in user's timezone)
  def events_by_date
    @events_by_date ||= all_events.group_by { |event| event.start_time.to_date }
  end

  # Get summary statistics
  # @return [ActivitySchedulingService::AgendaSummary] summary data object with event statistics
  def summary
    ActivitySchedulingService::AgendaSummary.new(
      total_suggestions: suggestions.count,
      total_existing: existing_events.count,
      total_events: all_events.count,
      suggestions_by_type: suggestions.group_by(&:type).transform_values(&:count),
      conflicts_avoided: suggestions.count(&:conflict_avoided?),
      date_range_start: date_range.begin,
      date_range_end: date_range.end,
      urgent_deadlines: suggestions.select { |s| s.urgency == "overdue" || s.urgency == "upcoming" }
    )
  end

  # Check if there are any events to display
  def any_events?
    existing_events.any? || suggestions.any?
  end

  # Check if user has Google Calendar connected
  def google_calendar_connected?
    existing_events.any? || suggestions.any? { |s| s.has_conflict? || s.conflict_avoided? }
  end
end
