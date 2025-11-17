# Model representing user activities for scheduling and management.
# Handles different schedule types, validation, and archiving functionality.
class Activity < ApplicationRecord
  belongs_to :user
  has_many :playlist_activities, dependent: :destroy
  has_many :playlists, through: :playlist_activities
  has_many :ai_suggestions, class_name: "AiActivitySuggestion", foreign_key: :final_activity_id, dependent: :nullify

  # Valid schedule types for activities
  # @return [Array<String>] frozen array of valid schedule types: strict, flexible, deadline, recurring_strict
  SCHEDULE_TYPES = %w[strict flexible deadline recurring_strict].freeze

  MAX_FREQUENCY_OPTIONS = [ 1, 30, 60, 90, 180, 365, nil ].freeze  # Days: 1 day, 1 month, 2 months, 3 months, 6 months, 12 months, never

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :slug, presence: true, uniqueness: true
  validates :schedule_type, inclusion: { in: SCHEDULE_TYPES }
  validates :max_frequency_days, inclusion: { in: MAX_FREQUENCY_OPTIONS }
  validates :description, length: { maximum: 1000 }, allow_blank: true

  # Custom validations for time consistency and business rules
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }
  validate :deadline_in_future, if: -> { deadline.present? }
  validate :strict_schedule_has_times, if: -> { schedule_type == "strict" }
  validate :deadline_schedule_has_deadline, if: -> { schedule_type == "deadline" }
  validate :recurring_strict_has_required_fields, if: -> { schedule_type == "recurring_strict" }
  validate :occurrence_end_time_after_start_time, if: -> { occurrence_time_start.present? && occurrence_time_end.present? }
  validate :valid_recurrence_rule, if: -> { recurring_strict? && recurrence_rule.present? }
  validate :duration_within_reasonable_bounds, if: -> { duration_minutes.present? }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :active, -> { where(archived_at: nil) }
  scope :owned_by, ->(user) { where(user: user) }

  def archived?
    archived_at.present?
  end

  # Archives the activity by setting archived_at timestamp
  # @return [Boolean] true if update succeeds, raises exception on failure
  def archive!
    update!(archived_at: Time.current)
  end

  # Archives the activity by setting archived_at timestamp (safe version)
  # @return [Boolean] true if update succeeds, false otherwise
  def archive
    update(archived_at: Time.current)
  end

  # Returns the slug for URL parameter usage
  # @return [String] the activity's slug for use in URLs
  def to_param
    slug
  end

  # Checks if activity has a strict schedule type
  # @return [Boolean] true if schedule_type is 'strict', false otherwise
  def strict_schedule?
    schedule_type == "strict"
  end

  def flexible_schedule?
    schedule_type == "flexible"
  end

  # Checks if activity has a deadline-based schedule type
  # @return [Boolean] true if schedule_type is 'deadline', false otherwise
  def deadline_based?
    schedule_type == "deadline"
  end

  # Checks if activity is a recurring event
  # @return [Boolean] true if schedule_type is 'recurring_strict', false otherwise
  def recurring_strict?
    schedule_type == "recurring_strict"
  end

  # Checks if activity has a deadline set
  # @return [Boolean] true if deadline is present, false otherwise
  def has_deadline?
    deadline.present?
  end

  # Checks if activity deadline has passed
  # @return [Boolean] true if has deadline and deadline is in the past, false otherwise
  def expired?
    has_deadline? && deadline < Time.current
  end

  # Parses and returns activity links from JSON storage
  # @return [Array] array of link objects, empty array if none or parse error
  def activity_links
    return [] unless links.present?

    JSON.parse(links)
  rescue JSON::ParserError
    []
  end

  # Sets activity links by converting data to JSON
  # @param link_data [Object] data to be converted to JSON and stored
  # @return [String] the JSON string that was stored
  def activity_links=(link_data)
    self.links = link_data.to_json
  end

  # Returns human-readable description of frequency interval
  # @return [String] descriptive text for the max_frequency_days value
  def max_frequency_description
    case max_frequency_days
    when 1 then "Daily"
    when 30 then "Monthly"
    when 60 then "Every 2 months"
    when 90 then "Every 3 months"
    when 180 then "Every 6 months"
    when 365 then "Yearly"
    when nil then "Never repeat"
    else "Every #{max_frequency_days} days"
    end
  end

  # AI-related helper methods

  # Returns formatted list of suggested months
  # @return [String] comma-separated month names or 'Any time' if none specified
  def formatted_suggested_months
    return "Any time" if suggested_months.blank?

    suggested_months.sort.map { |month| Date::MONTHNAMES[month] }.join(", ")
  end

  # Returns formatted list of suggested days of week
  # @return [String] comma-separated day names or 'Any day' if none specified
  def formatted_suggested_days
    return "Any day" if suggested_days_of_week.blank?

    suggested_days_of_week.sort.map { |day| Date::DAYNAMES[day] }.join(", ")
  end

  # Returns human-readable time of day suggestion
  # @return [String] time of day label or 'Flexible' if none specified
  def formatted_time_of_day
    return "Flexible" if suggested_time_of_day.blank?

    suggested_time_of_day.titleize
  end

  # Checks if activity was generated by AI
  # @return [Boolean] true if ai_generated flag is set
  def ai_generated?
    ai_generated == true
  end

  # Returns the original AI suggestion that created this activity
  # @return [AiActivitySuggestion, nil] the suggestion or nil if not AI-generated
  def originating_suggestion
    ai_suggestions.accepted.first
  end

  # Duration helper methods

  # Returns effective duration for the activity in minutes
  # @return [Integer] duration in minutes
  def effective_duration_minutes
    return duration_minutes if duration_minutes.present?
    return occurrence_duration_minutes if recurring_strict?
    return calculated_duration_minutes if strict_schedule? && start_time && end_time
    60 # Default to 60 minutes
  end

  # Calculate duration from occurrence times for recurring events
  # @return [Integer, nil] duration in minutes or nil if times not set
  def occurrence_duration_minutes
    return nil unless occurrence_time_start && occurrence_time_end

    start_mins = occurrence_time_start.hour * 60 + occurrence_time_start.min
    end_mins = occurrence_time_end.hour * 60 + occurrence_time_end.min

    end_mins - start_mins
  end

  # Calculate duration from start/end datetime for strict events
  # @return [Integer, nil] duration in minutes or nil if times not set
  def calculated_duration_minutes
    return nil unless start_time && end_time
    ((end_time - start_time) / 60).to_i
  end

  # Check if this is a time-windowed event (user attends less than full event)
  # @return [Boolean] true if activity has shorter duration than event window
  def time_windowed?
    return false unless strict_schedule? || recurring_strict?
    return false unless duration_minutes.present?

    event_duration = recurring_strict? ? occurrence_duration_minutes : calculated_duration_minutes
    event_duration && duration_minutes < event_duration
  end

  # For time-windowed events, get the window details
  # @return [Hash, nil] event window details or nil if not time-windowed
  def time_window
    return nil unless time_windowed?

    if recurring_strict?
      {
        start: occurrence_time_start,
        end: occurrence_time_end,
        duration: occurrence_duration_minutes,
        attendance_duration: duration_minutes
      }
    else
      {
        start: start_time,
        end: end_time,
        duration: calculated_duration_minutes,
        attendance_duration: duration_minutes
      }
    end
  end

  # Recurrence helper methods

  # Calculate next occurrence after a given date
  # @param from_date [Date] date to calculate from (defaults to today)
  # @return [DateTime, nil] next occurrence datetime or nil if none found
  def next_occurrence(from_date = Date.current)
    return nil unless recurring_strict?

    candidate = from_date
    max_iterations = 366 # Prevent infinite loops

    max_iterations.times do
      if matches_recurrence_pattern?(candidate)
        # Check if this date hasn't passed yet (including time)
        occurrence_datetime = combine_date_and_time(candidate, occurrence_time_start)
        return occurrence_datetime if occurrence_datetime > Time.current
      end

      candidate += 1.day

      # Stop if past end date
      return nil if recurrence_end_date && candidate > recurrence_end_date
    end

    nil # No occurrence found within 366 days
  end

  # Generate all occurrences within a date range
  # @param start_date [Date] start of range
  # @param end_date [Date] end of range
  # @return [Array<Hash>] array of occurrence hashes with :start_time, :end_time, :date
  def occurrences_in_range(start_date, end_date)
    return [] unless recurring_strict?

    occurrences = []
    current_date = [ start_date, recurrence_start_date ].max
    range_end = recurrence_end_date ? [ end_date, recurrence_end_date ].min : end_date

    while current_date <= range_end
      if matches_recurrence_pattern?(current_date)
        occurrence_start = combine_date_and_time(current_date, occurrence_time_start)
        occurrence_end = combine_date_and_time(current_date, occurrence_time_end)

        occurrences << {
          start_time: occurrence_start,
          end_time: occurrence_end,
          date: current_date
        }
      end

      current_date += 1.day
    end

    occurrences
  end

  # Check if a specific date matches the recurrence pattern
  # @param date [Date] date to check
  # @return [Boolean] true if date matches the pattern
  def matches_recurrence_pattern?(date)
    return false unless recurring_strict?
    return false if date < recurrence_start_date
    return false if recurrence_end_date && date > recurrence_end_date

    rule = recurrence_rule.with_indifferent_access
    freq = rule[:freq]
    interval = rule[:interval] || 1

    case freq
    when "DAILY"
      matches_daily_pattern?(date, interval)
    when "WEEKLY"
      matches_weekly_pattern?(date, interval, rule[:byday])
    when "MONTHLY"
      matches_monthly_pattern?(date, interval, rule)
    when "YEARLY"
      matches_yearly_pattern?(date, interval, rule)
    else
      false
    end
  end

  private

  def generate_slug
    base_slug = name.parameterize
    counter = 1
    potential_slug = base_slug

    while Activity.where(slug: potential_slug).exists?
      potential_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = potential_slug
  end

  # Custom validation methods for business logic
  def end_time_after_start_time
    return unless start_time && end_time

    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end

    # Ensure reasonable duration (max 12 hours for single activity)
    duration_hours = (end_time - start_time) / 1.hour
    if duration_hours > 12
      errors.add(:end_time, "activity duration cannot exceed 12 hours")
    end
  end

  def deadline_in_future
    return unless deadline

    if deadline <= Time.current
      errors.add(:deadline, "must be in the future")
    end

    # Ensure deadline is not too far in the future (max 2 years)
    if deadline > 2.years.from_now
      errors.add(:deadline, "cannot be more than 2 years in the future")
    end
  end

  def strict_schedule_has_times
    if start_time.blank? || end_time.blank?
      errors.add(:base, "Strict schedule activities must have both start and end times")
    end
  end

  def deadline_schedule_has_deadline
    if deadline.blank?
      errors.add(:deadline, "is required for deadline-based activities")
    end
  end

  def recurring_strict_has_required_fields
    if recurrence_rule.blank?
      errors.add(:recurrence_rule, "is required for recurring events")
    end

    if recurrence_start_date.blank?
      errors.add(:recurrence_start_date, "is required for recurring events")
    end

    if occurrence_time_start.blank?
      errors.add(:occurrence_time_start, "is required for recurring events")
    end

    if occurrence_time_end.blank?
      errors.add(:occurrence_time_end, "is required for recurring events")
    end
  end

  def occurrence_end_time_after_start_time
    return unless occurrence_time_start && occurrence_time_end

    start_mins = occurrence_time_start.hour * 60 + occurrence_time_start.min
    end_mins = occurrence_time_end.hour * 60 + occurrence_time_end.min

    if end_mins <= start_mins
      errors.add(:occurrence_time_end, "must be after start time")
    end
  end

  def valid_recurrence_rule
    return unless recurrence_rule.is_a?(Hash)

    valid_frequencies = %w[DAILY WEEKLY MONTHLY YEARLY]
    freq = recurrence_rule["freq"] || recurrence_rule[:freq]

    unless valid_frequencies.include?(freq)
      errors.add(:recurrence_rule, "must have valid freq: #{valid_frequencies.join(', ')}")
    end
  end

  def duration_within_reasonable_bounds
    if duration_minutes <= 0
      errors.add(:duration_minutes, "must be greater than 0")
    end

    if duration_minutes > 720 # 12 hours
      errors.add(:duration_minutes, "cannot exceed 720 minutes (12 hours)")
    end
  end

  # Recurrence pattern matching helpers

  def matches_daily_pattern?(date, interval)
    days_since_start = (date - recurrence_start_date).to_i
    (days_since_start % interval).zero?
  end

  def matches_weekly_pattern?(date, interval, byday)
    # Check if correct interval of weeks
    weeks_since_start = ((date - recurrence_start_date).to_i / 7)
    return false unless (weeks_since_start % interval).zero?

    # Check if correct day of week
    return true if byday.blank? # No day restriction

    day_abbr = date.strftime("%^a")[0..1] # SU, MO, TU, etc
    byday.map(&:to_s).include?(day_abbr)
  end

  def matches_monthly_pattern?(date, interval, rule)
    # Check if correct interval of months
    months_since_start = (date.year - recurrence_start_date.year) * 12 +
                         (date.month - recurrence_start_date.month)
    return false unless (months_since_start % interval).zero?

    # Check by month day (e.g., 15th of every month)
    if rule[:bymonthday].present?
      return rule[:bymonthday].map(&:to_i).include?(date.day)
    end

    # Check by position (e.g., 1st Sunday, last Friday)
    if rule[:byday].present? && rule[:bysetpos].present?
      day_abbr = date.strftime("%^a")[0..1]
      return false unless rule[:byday].map(&:to_s).include?(day_abbr)

      # Calculate which occurrence this is in the month
      occurrence_in_month = ((date.day - 1) / 7) + 1

      # Calculate from end of month for negative positions
      days_in_month = Date.civil(date.year, date.month, -1).day
      occurrence_from_end = -(((days_in_month - date.day) / 7) + 1)

      rule[:bysetpos].map(&:to_i).each do |pos|
        return true if pos > 0 && pos == occurrence_in_month
        return true if pos < 0 && pos == occurrence_from_end
      end

      return false
    end

    true # No day restriction
  end

  def matches_yearly_pattern?(date, interval, rule)
    years_since_start = date.year - recurrence_start_date.year
    return false unless (years_since_start % interval).zero?

    # Check if same month and day
    date.month == recurrence_start_date.month &&
    date.day == recurrence_start_date.day
  end

  def combine_date_and_time(date, time)
    return nil unless date && time

    Time.zone.local(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.min,
      time.sec
    )
  end
end
