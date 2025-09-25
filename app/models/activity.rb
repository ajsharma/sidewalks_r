# Model representing user activities for scheduling and management.
# Handles different schedule types, validation, and archiving functionality.
class Activity < ApplicationRecord
  belongs_to :user
  has_many :playlist_activities, dependent: :destroy
  has_many :playlists, through: :playlist_activities

  SCHEDULE_TYPES = %w[strict flexible deadline].freeze
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
end
