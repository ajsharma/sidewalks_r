# Model representing external events parsed from RSS/Atom feeds.
# Events are global (visible to all users) and can be converted to user-specific Activities.
# == Schema Information
#
# Table name: external_events
#
#  id             :bigint           not null, primary key
#  archived_at    :datetime
#  category_tags  :string           default([]), is an Array
#  description    :text
#  end_time       :datetime
#  last_synced_at :datetime
#  location       :string
#  organizer      :string
#  price          :decimal(10, 2)
#  price_details  :string
#  source_url     :text             not null
#  start_time     :datetime         not null
#  title          :string           not null
#  venue          :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  event_feed_id  :bigint           not null
#  external_id    :string
#
# Indexes
#
#  index_external_events_on_archived_at                    (archived_at)
#  index_external_events_on_category_tags                  (category_tags) USING gin
#  index_external_events_on_event_feed_id                  (event_feed_id)
#  index_external_events_on_event_feed_id_and_external_id  (event_feed_id,external_id) UNIQUE
#  index_external_events_on_start_time                     (start_time)
#
# Foreign Keys
#
#  fk_rails_...  (event_feed_id => event_feeds.id)
#
class ExternalEvent < ApplicationRecord
  belongs_to :event_feed

  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :start_time, presence: true
  validates :source_url, presence: true
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  scope :active, -> { where(archived_at: nil) }
  scope :upcoming, -> { where("start_time >= ?", Time.current) }
  scope :by_date_range, ->(start_date, end_date) { where(start_time: start_date.beginning_of_day..end_date.end_of_day) }
  scope :free_only, -> { where(price: [ nil, 0 ]) }
  scope :weekends_only, -> { where("EXTRACT(DOW FROM start_time) IN (0, 6)") } # 0 = Sunday, 6 = Saturday
  scope :search_by_text, ->(query) {
    sanitized_query = sanitize_sql_like(query)
    where("title ILIKE ? OR description ILIKE ? OR venue ILIKE ?",
          "%#{sanitized_query}%", "%#{sanitized_query}%", "%#{sanitized_query}%")
  }

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def free?
    price.nil? || price.zero?
  end

  def weekend?
    start_time.wday.in?([ 0, 6 ]) # Sunday or Saturday
  end

  def duration_hours
    return nil unless end_time
    ((end_time - start_time) / 1.hour).round(1)
  end

  # Convert external event to Activity parameters for creation
  # @param user [User] the user who will own the activity
  # @return [Hash] parameters suitable for Activity.create
  def to_activity_params(user)
    {
      user: user,
      name: title,
      description: description,
      schedule_type: "strict",
      start_time: start_time,
      end_time: end_time,
      source_url: source_url,
      price: price,
      organizer: organizer,
      category_tags: category_tags,
      image_url: nil,
      ai_generated: false,
      duration_minutes: duration_hours ? (duration_hours * 60).to_i : nil
    }
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end

    # Validate duration is not unreasonably long (max 24 hours for events)
    duration = (end_time - start_time) / 1.hour
    if duration > 24
      errors.add(:end_time, "event duration cannot exceed 24 hours")
    end
  end
end
