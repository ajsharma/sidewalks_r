# Service for synchronizing events from RSS feeds to the database.
# Handles deduplication, creation, and updates of external events.
class EventSyncService
  attr_reader :feed, :results

  def initialize(event_feed)
    @feed = event_feed
    @results = {
      success: false,
      events_added: 0,
      events_updated: 0,
      events_skipped: 0,
      errors: []
    }
  end

  # Sync events from the feed
  # @return [Hash] results hash with counts and errors
  def sync
    parser = RssParserService.new(@feed.url)
    event_hashes = parser.parse

    Rails.logger.info("Fetched #{event_hashes.count} events from #{@feed.name}")

    event_hashes.each do |event_data|
      sync_event(event_data)
    end

    @feed.mark_fetched!(count: @feed.external_events.active.count)
    @results[:success] = true
    @results
  rescue RssParserService::FetchError => e
    error_message = "Feed fetch failed: #{e.message}"
    Rails.logger.error("#{@feed.name}: #{error_message}")
    @feed.mark_fetched!(error: error_message)
    @results[:errors] << error_message
    @results
  rescue RssParserService::ParseError => e
    error_message = "Feed parse failed: #{e.message}"
    Rails.logger.error("#{@feed.name}: #{error_message}")
    @feed.mark_fetched!(error: error_message)
    @results[:errors] << error_message
    @results
  rescue StandardError => e
    error_message = "Unexpected error: #{e.message}"
    Rails.logger.error("#{@feed.name}: #{error_message}\n#{e.backtrace.first(5).join("\n")}")
    @feed.mark_fetched!(error: error_message)
    @results[:errors] << error_message
    @results
  end

  private

  def sync_event(event_data)
    # Try to find existing event by external_id
    existing_event = @feed.external_events.find_by(external_id: event_data[:external_id])

    if existing_event
      update_event(existing_event, event_data)
    else
      create_event(event_data)
    end
  rescue ActiveRecord::RecordInvalid => e
    @results[:errors] << "Failed to sync event '#{event_data[:title]}': #{e.message}"
    @results[:events_skipped] += 1
  rescue StandardError => e
    @results[:errors] << "Unexpected error syncing '#{event_data[:title]}': #{e.message}"
    @results[:events_skipped] += 1
  end

  def create_event(event_data)
    # Check if a very similar event already exists (fuzzy deduplication)
    # This handles cases where external_id might change but it's the same event
    similar_event = find_similar_event(event_data)

    if similar_event
      update_event(similar_event, event_data)
    else
      event = @feed.external_events.create!(
        title: event_data[:title],
        description: event_data[:description],
        start_time: event_data[:start_time],
        end_time: event_data[:end_time],
        location: event_data[:location],
        venue: event_data[:venue],
        source_url: event_data[:source_url],
        price: event_data[:price],
        price_details: event_data[:price_details],
        organizer: event_data[:organizer],
        category_tags: event_data[:category_tags] || [],
        external_id: event_data[:external_id],
        last_synced_at: Time.current
      )

      @results[:events_added] += 1
      Rails.logger.debug("Created event: #{event.title} (#{event.start_time})")
    end
  end

  def update_event(event, event_data)
    # Only update if data has changed
    changes = {}

    changes[:title] = event_data[:title] if event.title != event_data[:title]
    changes[:description] = event_data[:description] if event.description != event_data[:description]
    changes[:start_time] = event_data[:start_time] if event.start_time != event_data[:start_time]
    changes[:end_time] = event_data[:end_time] if event.end_time != event_data[:end_time]
    changes[:location] = event_data[:location] if event.location != event_data[:location]
    changes[:venue] = event_data[:venue] if event.venue != event_data[:venue]
    changes[:source_url] = event_data[:source_url] if event.source_url != event_data[:source_url]
    changes[:price] = event_data[:price] if event.price != event_data[:price]
    changes[:organizer] = event_data[:organizer] if event.organizer != event_data[:organizer]
    changes[:category_tags] = event_data[:category_tags] if event.category_tags != event_data[:category_tags]
    changes[:last_synced_at] = Time.current

    if changes.any?
      event.update!(changes)
      @results[:events_updated] += 1
      Rails.logger.debug("Updated event: #{event.title}")
    else
      # Mark as synced even if no changes
      event.update!(last_synced_at: Time.current)
      @results[:events_skipped] += 1
    end
  end

  def find_similar_event(event_data)
    # Find event with same source_url OR (similar title and same start time)
    # This helps catch duplicate events across feeds or when external_id changes

    # First try exact source_url match
    return @feed.external_events.find_by(source_url: event_data[:source_url]) if event_data[:source_url].present?

    # Then try fuzzy match: similar title + same day/time
    return nil unless event_data[:title].present? && event_data[:start_time].present?

    # Search for events within 1 hour of start time with similar title
    time_window = 1.hour
    @feed.external_events
         .where(start_time: (event_data[:start_time] - time_window)..(event_data[:start_time] + time_window))
         .find do |existing|
      title_similarity = calculate_title_similarity(existing.title, event_data[:title])
      title_similarity > 0.8 # 80% similarity threshold
    end
  end

  def calculate_title_similarity(title1, title2)
    # Simple Jaccard similarity based on word sets
    words1 = title1.downcase.split(/\W+/).to_set
    words2 = title2.downcase.split(/\W+/).to_set

    return 0.0 if words1.empty? || words2.empty?

    intersection = (words1 & words2).size.to_f
    union = (words1 | words2).size.to_f

    intersection / union
  end
end
