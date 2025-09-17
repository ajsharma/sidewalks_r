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
    when 'calendar'
      raw_data[:summary] || 'Busy'
    when 'suggestion'
      raw_data[:title]
    end
  end

  def start_time
    @start_time ||= normalize_time(raw_data[:start_time])
  end

  def end_time
    @end_time ||= normalize_time(raw_data[:end_time])
  end

  def duration
    end_time - start_time
  end

  def type
    case source
    when 'calendar'
      'existing'
    when 'suggestion'
      raw_data[:type]
    end
  end

  # Calendar-specific attributes
  def calendar_name
    raw_data[:calendar_name] if source == 'calendar'
  end

  # Activity suggestion-specific attributes
  def confidence
    raw_data[:confidence] if source == 'suggestion'
  end

  def urgency
    raw_data[:urgency] if source == 'suggestion'
  end

  def frequency_note
    raw_data[:frequency_note] if source == 'suggestion'
  end

  def has_conflict?
    raw_data[:has_conflict] == true
  end

  def conflict_avoided?
    raw_data[:conflict_avoided] == true
  end

  def notes
    raw_data[:notes] || []
  end

  # Check if this is an existing calendar event
  def existing_event?
    source == 'calendar'
  end

  # Check if this is a suggested activity
  def suggested_activity?
    source == 'suggestion'
  end

  # Get the original activity or calendar event data
  def activity
    raw_data[:activity] if source == 'suggestion'
  end

  def calendar_id
    raw_data[:calendar_id] if source == 'calendar'
  end


  private

  def normalize_time(time)
    return nil unless time

    # Convert to user's timezone
    time.in_time_zone(user_timezone)
  end
end