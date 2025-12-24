# Background job for fetching and syncing events from RSS feeds.
# Runs periodically to keep the external events database up-to-date.
class FetchEventFeedsJob < ApplicationJob
  queue_as :event_feeds

  # Retry strategies for transient failures
  retry_on RssParserService::FetchError, wait: :exponentially_longer, attempts: 3
  retry_on Net::OpenTimeout, Net::ReadTimeout, SocketError, wait: 30.seconds, attempts: 2

  # Discard strategies for permanent failures
  discard_on RssParserService::InvalidUrlError
  discard_on ActiveRecord::RecordNotFound

  def perform(feed_id = nil)
    if feed_id
      # Fetch a specific feed
      feed = EventFeed.find(feed_id)
      sync_feed(feed)
    else
      # Fetch all active feeds
      feeds = EventFeed.active
      Rails.logger.info("Fetching #{feeds.count} active event feeds")

      feeds.find_each do |feed|
        sync_feed(feed)
      end

      # Archive old events (older than 7 days past start_time)
      archive_old_events
    end
  end

  private

  def sync_feed(feed)
    Rails.logger.info("Syncing feed: #{feed.name} (#{feed.url})")

    service = EventSyncService.new(feed)
    results = service.sync

    if results[:success]
      Rails.logger.info(
        "#{feed.name}: Added #{results[:events_added]}, " \
        "Updated #{results[:events_updated]}, " \
        "Skipped #{results[:events_skipped]}"
      )

      feed.clear_error! if feed.last_error.present?
    else
      Rails.logger.error("#{feed.name}: Failed with #{results[:errors].count} errors")
      results[:errors].each { |error| Rails.logger.error("  - #{error}") }
    end
  rescue StandardError => e
    Rails.logger.error("Fatal error syncing #{feed.name}: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    feed.mark_fetched!(error: "Fatal error: #{e.message}")
    raise # Re-raise to trigger retry logic
  end

  def archive_old_events
    cutoff_date = 7.days.ago
    old_events = ExternalEvent.active.where("start_time < ?", cutoff_date)
    count = old_events.count

    if count > 0
      old_events.update_all(archived_at: Time.current)
      Rails.logger.info("Archived #{count} old events")
    end
  end
end
