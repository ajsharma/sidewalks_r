# Domain object representing a single proposed event in an agenda.
# Wraps event data with timezone-aware time handling.
class AgendaProposedEvent
  attr_reader :raw_data, :user_timezone, :source

  def initialize(data, user_timezone:, source:)
    @raw_data = data
    @user_timezone = user_timezone
    @source = source # 'calendar' or 'suggestion'
  end

  # Unified interface for both calendar events and activity suggestions
  def title
    case source
    when "calendar"
      raw_data[:summary] || "Busy"
    when "suggestion"
      raw_data[:title]
    end
  end

  # Returns the event start time in the user's timezone
  # @return [ActiveSupport::TimeWithZone, nil] normalized start time or nil if not present
  def start_time
    @start_time ||= normalize_time(raw_data[:start_time])
  end

  # Returns the event end time in the user's timezone
  # @return [ActiveSupport::TimeWithZone, nil] normalized end time or nil if not present
  def end_time
    @end_time ||= normalize_time(raw_data[:end_time])
  end

  # Calculates the duration of the event in seconds
  # @return [Float] duration in seconds between start and end time
  def duration
    end_time - start_time
  end

  # Returns the type of event: 'existing' for calendar events or activity type for suggestions
  # @return [String] event type identifier
  def type
    case source
    when "calendar"
      "existing"
    when "suggestion"
      raw_data[:type]
    end
  end

  # Calendar-specific attributes
  def calendar_name
    raw_data[:calendar_name] if source == "calendar"
  end

  # Activity suggestion-specific attributes
  def confidence
    raw_data[:confidence] if source == "suggestion"
  end

  # Returns urgency level for suggested activities
  # @return [String, nil] urgency level (e.g., 'high', 'medium', 'low') or nil if not a suggestion
  def urgency
    raw_data[:urgency] if source == "suggestion"
  end

  # Returns frequency information for suggested activities
  # @return [String, nil] human-readable frequency note or nil if not a suggestion
  def frequency_note
    raw_data[:frequency_note] if source == "suggestion"
  end

  def has_conflict?
    raw_data[:has_conflict] == true
  end

  def conflict_avoided?
    raw_data[:conflict_avoided] == true
  end

  # Returns additional notes or metadata about the event
  # @return [Array] array of note strings, empty array if none
  def notes
    raw_data[:notes] || []
  end

  # Check if this is an existing calendar event
  def existing_event?
    source == "calendar"
  end

  # Check if this is a suggested activity
  def suggested_activity?
    source == "suggestion"
  end

  # Get the original activity or calendar event data
  def activity
    raw_data[:activity] if source == "suggestion"
  end

  # Returns the Google Calendar ID for calendar events
  # @return [String, nil] calendar ID or nil if not a calendar event
  def calendar_id
    raw_data[:calendar_id] if source == "calendar"
  end


  private

  def normalize_time(time)
    return nil unless time

    # Convert to user's timezone
    time.in_time_zone(user_timezone)
  end
end
