# Model representing RSS/Atom feed sources for external events.
# Tracks feed metadata, health status, and manages periodic fetching.
# == Schema Information
#
# Table name: event_feeds
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  url             :string           not null
#  feed_type       :string           default("rss")
#  active          :boolean          default(TRUE)
#  last_fetched_at :datetime
#  last_error      :text
#  event_count     :integer          default(0)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_event_feeds_on_active           (active)
#  index_event_feeds_on_last_fetched_at  (last_fetched_at)
#
class EventFeed < ApplicationRecord
  has_many :external_events, dependent: :destroy

  FEED_TYPES = %w[rss atom].freeze

  # Whitelist of allowed feed URLs for SSRF protection
  ALLOWED_FEED_URLS = [
    "https://www.bottomofthehill.com/RSS.xml",
    "https://sf.funcheap.com/rss-date/",
    "https://www.eddies-list.com/feed"
  ].freeze

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :url, inclusion: { in: ALLOWED_FEED_URLS, message: "must be from an allowed feed source" }
  validates :feed_type, inclusion: { in: FEED_TYPES }

  scope :active, -> { where(active: true) }
  scope :needs_refresh, ->(hours_ago = 6) { where("last_fetched_at IS NULL OR last_fetched_at < ?", hours_ago.hours.ago) }

  def active?
    active
  end

  def stale?(hours = 6)
    last_fetched_at.nil? || last_fetched_at < hours.hours.ago
  end

  def mark_fetched!(count: nil, error: nil)
    updates = { last_fetched_at: Time.current }
    updates[:event_count] = count if count
    updates[:last_error] = error
    update!(updates)
  end

  def clear_error!
    update!(last_error: nil)
  end
end
