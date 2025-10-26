# Helper methods for Activities views and forms
module ActivitiesHelper
  # Returns options for schedule type select field
  # @return [Array<Array>] array of [label, value] pairs for schedule type dropdown
  def schedule_type_options
    [
      [ "Flexible - Can be done anytime", "flexible" ],
      [ "Strict - Specific date and time", "strict" ],
      [ "Deadline - Must be done before a certain date", "deadline" ]
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
end
