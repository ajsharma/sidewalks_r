# Helper methods for AI activity suggestions views
module AiActivitiesHelper
  # Returns options for schedule type select dropdown for AI suggestions
  # @return [Array<Array<String>>] array of [label, value] pairs
  def ai_schedule_type_options
    [
      ['Flexible - Can happen anytime', 'flexible'],
      ['Strict - Specific date/time', 'strict'],
      ['Deadline - Must complete by date', 'deadline'],
      ['Recurring - Repeats on a schedule', 'recurring_strict']
    ]
  end

  # Returns options for time of day select dropdown for AI suggestions
  # @return [Array<Array<String>>] array of [label, value] pairs
  def ai_time_of_day_options
    [
      ['Flexible', ''],
      ['Morning (6am-12pm)', 'morning'],
      ['Afternoon (12pm-5pm)', 'afternoon'],
      ['Evening (5pm-9pm)', 'evening'],
      ['Night (9pm-late)', 'night']
    ]
  end

  # Returns a formatted relative time string
  # @param time [Time, DateTime] the time to format
  # @return [String] formatted relative time (e.g., "2 days ago")
  # :reek:UtilityFunction
  def relative_time(time)
    return '' unless time

    distance = Time.current - time
    case distance
    when 0..59
      'just now'
    when 60..3599
      "#{(distance / 60).round} minutes ago"
    when 3600..86399
      "#{(distance / 3600).round} hours ago"
    when 86400..604799
      "#{(distance / 86400).round} days ago"
    when 604800..2419199
      "#{(distance / 604800).round} weeks ago"
    else
      time.strftime('%b %d, %Y')
    end
  end
end
