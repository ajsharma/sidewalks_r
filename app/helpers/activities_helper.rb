module ActivitiesHelper
  def schedule_type_options
    [
      ['Flexible - Can be done anytime', 'flexible'],
      ['Strict - Specific date and time', 'strict'],
      ['Deadline - Must be done before a certain date', 'deadline']
    ]
  end

  def max_frequency_options
    [
      ['Daily', 1],
      ['Monthly', 30],
      ['Every 2 months', 60],
      ['Every 3 months', 90],
      ['Every 6 months', 180],
      ['Yearly', 365],
      ['Never repeat', nil]
    ]
  end
end