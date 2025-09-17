class Activity < ApplicationRecord
  belongs_to :user

  SCHEDULE_TYPES = %w[strict flexible deadline].freeze
  MAX_FREQUENCY_OPTIONS = [ 1, 30, 60, 90, 180, 365, nil ].freeze  # Days: 1 day, 1 month, 2 months, 3 months, 6 months, 12 months, never

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :schedule_type, inclusion: { in: SCHEDULE_TYPES }
  validates :max_frequency_days, inclusion: { in: MAX_FREQUENCY_OPTIONS }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :active, -> { where(archived_at: nil) }
  scope :by_schedule_type, ->(type) { where(schedule_type: type) }
  scope :strict_schedule, -> { where(schedule_type: "strict") }
  scope :flexible_schedule, -> { where(schedule_type: "flexible") }
  scope :deadline_based, -> { where(schedule_type: "deadline") }

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def to_param
    slug
  end

  def strict_schedule?
    schedule_type == "strict"
  end

  def flexible_schedule?
    schedule_type == "flexible"
  end

  def deadline_based?
    schedule_type == "deadline"
  end

  def has_deadline?
    deadline.present?
  end

  def expired?
    has_deadline? && deadline < Time.current
  end

  def activity_links
    return [] unless links.present?

    JSON.parse(links)
  rescue JSON::ParserError
    []
  end

  def activity_links=(link_data)
    self.links = link_data.to_json
  end

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
end
