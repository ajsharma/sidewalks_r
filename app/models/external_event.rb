# Model representing external events parsed from RSS/Atom feeds.
# Events are global (visible to all users) and can be converted to user-specific Activities.
# == Schema Information
#
# Table name: external_events
#
#  id                                                      :bigint           not null, primary key
#  archived_at                                             :datetime
#  category_tags                                           :string           default([]), is an Array
#  description                                             :text
#  end_time                                                :datetime
#  last_synced_at                                          :datetime
#  location                                                :string
#  organizer                                               :string
#  price                                                   :decimal(10, 2)
#  price_details                                           :string
#  raw_data(Raw RSS/Atom feed entry data for reprocessing) :jsonb
#  source_url                                              :text             not null
#  start_time                                              :datetime         not null
#  title                                                   :string           not null
#  venue                                                   :string
#  created_at                                              :datetime         not null
#  updated_at                                              :datetime         not null
#  event_feed_id                                           :bigint           not null
#  external_id                                             :string
#
# Indexes
#
#  index_external_events_on_archived_at                    (archived_at)
#  index_external_events_on_category_tags                  (category_tags) USING gin
#  index_external_events_on_event_feed_id                  (event_feed_id)
#  index_external_events_on_event_feed_id_and_external_id  (event_feed_id,external_id) UNIQUE
#  index_external_events_on_raw_data                       (raw_data) USING gin
#  index_external_events_on_start_time                     (start_time)
#
# Foreign Keys
#
#  fk_rails_...  (event_feed_id => event_feeds.id)
#
class ExternalEvent < ApplicationRecord
  # Explicitly set table name to avoid conflicts with model_name override
  self.table_name = "external_events"

  belongs_to :event_feed

  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :start_time, presence: true
  validates :source_url, presence: true
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  # Tell Rails to use 'events' routes for this model
  def self.model_name
    @model_name ||= ActiveModel::Name.new(self, nil, "Event")
  end

  scope :active, -> { where(archived_at: nil) }
  scope :upcoming, -> { where("start_time >= ?", Time.current.beginning_of_day) }
  scope :by_date_range, ->(start_date, end_date) { where(start_time: start_date.beginning_of_day..end_date.end_of_day) }
  scope :free_only, -> { where(price: [ nil, 0 ]) }
  scope :weekends_only, -> { where("EXTRACT(DOW FROM start_time) IN (0, 6)") } # 0 = Sunday, 6 = Saturday
  scope :search_by_text, ->(query) {
    sanitized_query = sanitize_sql_like(query)
    where("title ILIKE ? OR description ILIKE ? OR venue ILIKE ?",
          "%#{sanitized_query}%", "%#{sanitized_query}%", "%#{sanitized_query}%")
  }

  # Scope to apply filters from filter options hash
  # @param options [Hash] Filter options (parsed dates, booleans, etc.)
  # @return [ActiveRecord::Relation] Filtered events
  scope :apply_filters, ->(options = {}) {
    relation = all

    # Date range filter
    if options[:start_date] && options[:end_date]
      relation = relation.by_date_range(options[:start_date], options[:end_date])
    end

    # Weekends only filter
    relation = relation.weekends_only if options[:weekends_only]

    # Free events filter
    relation = relation.free_only if options[:free_only]

    # Price max filter
    relation = relation.where("price IS NULL OR price <= ?", options[:price_max]) if options[:price_max]

    # Category filter
    relation = relation.where("? = ANY(category_tags)", options[:category]) if options[:category].present?

    # Search filter
    relation = relation.search_by_text(options[:search]) if options[:search].present?

    relation
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

  # Reprocess this event from its raw feed data
  # Useful after fixing parser bugs or adding new features
  # @return [Boolean] true if reprocessed successfully
  def reprocess_from_raw_data!
    return false unless raw_data.present?
    return false unless raw_data["feed_url"].present?

    # Parse the raw data again using the current parser
    parser = RssParserService.new(raw_data["feed_url"])

    # Create a mock entry from the raw data
    # This is a simplified approach - we'd need to properly reconstruct the entry
    # For now, we'll just re-fetch the feed and find the matching entry
    events = parser.parse
    matching_event = events.find { |e| e[:source_url] == source_url }

    return false unless matching_event

    # Update this event with the reprocessed data
    update!(
      title: matching_event[:title],
      description: matching_event[:description],
      start_time: matching_event[:start_time],
      end_time: matching_event[:end_time],
      location: matching_event[:location],
      venue: matching_event[:venue],
      price: matching_event[:price],
      organizer: matching_event[:organizer],
      category_tags: matching_event[:category_tags],
      raw_data: matching_event[:raw_data],
      last_synced_at: Time.current
    )

    true
  rescue StandardError => e
    Rails.logger.error("Failed to reprocess event #{id}: #{e.message}")
    false
  end

  # Class method to reprocess all events or events from a specific feed
  # @param feed_id [Integer, nil] optional feed ID to limit reprocessing
  # @return [Hash] counts of successful and failed reprocessing
  def self.reprocess_all(feed_id: nil)
    scope = feed_id ? where(event_feed_id: feed_id) : all
    events_to_process = scope.where.not(raw_data: nil)

    successful = 0
    failed = 0

    events_to_process.find_each do |event|
      if event.reprocess_from_raw_data!
        successful += 1
      else
        failed += 1
      end
    end

    { successful: successful, failed: failed, total: events_to_process.count }
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
