# Helper methods for Activities views and forms
module ActivitiesHelper
  # Returns options for schedule type select field
  # @return [Array<Array>] array of [label, value] pairs for schedule type dropdown
  def schedule_type_options
    [
      [ "Flexible - Can be done anytime", "flexible" ],
      [ "Strict - Specific date and time", "strict" ],
      [ "Deadline - Must be done before a certain date", "deadline" ],
      [ "Recurring - Repeats on a schedule", "recurring_strict" ]
    ]
  end

  # Returns options for max frequency select field
  # @return [Array<Array>] array of [label, value] pairs for frequency dropdown, values in days
  def max_frequency_options
    [
      [ "Daily", 1 ],
      [ "Monthly", 30 ],
      [ "Every 2 months", 60 ],
      [ "Every 3 months", 90 ],
      [ "Every 6 months", 180 ],
      [ "Yearly", 365 ],
      [ "Never repeat", nil ]
    ]
  end

  # Returns options for recurrence frequency
  # @return [Array<Array>] array of [label, value] pairs for frequency dropdown
  def recurrence_frequency_options
    [
      [ "Daily", "DAILY" ],
      [ "Weekly", "WEEKLY" ],
      [ "Monthly", "MONTHLY" ],
      [ "Yearly", "YEARLY" ]
    ]
  end

  # Returns options for days of the week
  # @return [Array<Array>] array of [label, value] pairs for day selection
  def day_of_week_options
    [
      [ "Sunday", "SU" ],
      [ "Monday", "MO" ],
      [ "Tuesday", "TU" ],
      [ "Wednesday", "WE" ],
      [ "Thursday", "TH" ],
      [ "Friday", "FR" ],
      [ "Saturday", "SA" ]
    ]
  end

  # Returns options for monthly recurrence by position
  # @return [Array<Array>] array of [label, value] pairs for position selection
  def monthly_position_options
    [
      [ "First", 1 ],
      [ "Second", 2 ],
      [ "Third", 3 ],
      [ "Fourth", 4 ],
      [ "Last", -1 ]
    ]
  end
end
