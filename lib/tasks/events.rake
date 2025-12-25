namespace :events do
  desc "Fetch and sync all RSS event feeds"
  task fetch: :environment do
    puts "Fetching RSS event feeds..."
    puts "=" * 60

    start_time = Time.current
    initial_count = ExternalEvent.count

    # Perform the fetch job
    FetchEventFeedsJob.perform_now

    end_time = Time.current
    final_count = ExternalEvent.count
    new_events = final_count - initial_count

    puts "\n" + "=" * 60
    puts "Fetch Complete!"
    puts "  Duration: #{(end_time - start_time).round(2)}s"
    puts "  Events added: #{new_events}"
    puts "  Total events: #{final_count}"
    puts "=" * 60
  end

  desc "Show summary of events and feeds"
  task summary: :environment do
    puts "\n" + "=" * 60
    puts "EVENT DISCOVERY SUMMARY"
    puts "=" * 60

    # Overall stats
    total_events = ExternalEvent.count
    active_events = ExternalEvent.active.count
    upcoming_events = ExternalEvent.active.upcoming.count
    archived_events = ExternalEvent.where.not(archived_at: nil).count

    puts "\nOVERALL STATISTICS:"
    puts "  Total events: #{total_events}"
    puts "  Active events: #{active_events}"
    puts "  Upcoming events: #{upcoming_events}"
    puts "  Archived events: #{archived_events}"

    # Feed breakdown
    puts "\nFEED BREAKDOWN:"
    EventFeed.all.order(:name).each do |feed|
      status_icon = feed.active? ? "✓" : "✗"
      error_indicator = feed.last_error.present? ? " ⚠️" : ""

      puts "\n  #{status_icon} #{feed.name}#{error_indicator}"
      puts "     URL: #{feed.url}"
      puts "     Type: #{feed.feed_type}"
      puts "     Events: #{feed.event_count}"
      puts "     Last fetched: #{feed.last_fetched_at&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"

      if feed.last_error.present?
        puts "     Last error: #{feed.last_error}"
      end
    end

    # Date range of events
    if upcoming_events > 0
      earliest = ExternalEvent.active.upcoming.minimum(:start_time)
      latest = ExternalEvent.active.upcoming.maximum(:start_time)

      puts "\nUPCOMING EVENT DATE RANGE:"
      puts "  Earliest: #{earliest&.strftime('%B %d, %Y at %I:%M %p')}"
      puts "  Latest: #{latest&.strftime('%B %d, %Y at %I:%M %p')}"
    end

    # Category breakdown (top 10)
    all_tags = ExternalEvent.active.pluck(:category_tags).flatten.compact
    tag_counts = all_tags.group_by(&:itself).transform_values(&:count).sort_by { |_, count| -count }.first(10)

    if tag_counts.any?
      puts "\nTOP CATEGORIES:"
      tag_counts.each_with_index do |(tag, count), index|
        puts "  #{index + 1}. #{tag}: #{count} events"
      end
    end

    # Price breakdown
    free_count = ExternalEvent.active.upcoming.free_only.count
    paid_count = ExternalEvent.active.upcoming.where.not(price: [ nil, 0 ]).count

    puts "\nPRICE BREAKDOWN:"
    puts "  Free events: #{free_count}"
    puts "  Paid events: #{paid_count}"
    puts "  No price info: #{upcoming_events - free_count - paid_count}"

    # Weekend events
    weekend_count = ExternalEvent.active.upcoming.weekends_only.count

    puts "\nSCHEDULE:"
    puts "  Weekend events: #{weekend_count}"
    puts "  Weekday events: #{upcoming_events - weekend_count}"

    # Recent activity
    recent_synced = ExternalEvent.where("last_synced_at >= ?", 24.hours.ago).count

    puts "\nRECENT ACTIVITY (last 24 hours):"
    puts "  Events synced: #{recent_synced}"

    puts "\n" + "=" * 60
    puts "Run 'rake events:fetch' to refresh feeds"
    puts "Visit http://localhost:3000/events to browse"
    puts "=" * 60 + "\n"
  end

  desc "Show upcoming events (default: next 7 days)"
  task :upcoming, [ :days ] => :environment do |_t, args|
    days = (args[:days] || 7).to_i
    end_date = days.days.from_now

    puts "\n" + "=" * 60
    puts "UPCOMING EVENTS (Next #{days} days)"
    puts "=" * 60

    events = ExternalEvent.active
                          .upcoming
                          .where("start_time <= ?", end_date)
                          .order(start_time: :asc)
                          .limit(50)

    if events.any?
      events.group_by { |e| e.start_time.to_date }.each do |date, day_events|
        puts "\n#{date.strftime('%A, %B %d, %Y')} (#{day_events.count} events)"
        puts "-" * 60

        day_events.each do |event|
          time = event.start_time.strftime("%I:%M %p")
          price = event.free? ? "[FREE]" : (event.price ? "[$#{event.price}]" : "")
          venue = event.venue ? " @ #{event.venue}" : ""

          puts "  #{time} - #{event.title} #{price}#{venue}"
        end
      end

      puts "\n" + "=" * 60
      puts "Showing #{events.count} events"
      puts "=" * 60 + "\n"
    else
      puts "\nNo upcoming events found.\n\n"
    end
  end

  desc "Clean up old archived events (default: older than 30 days)"
  task :cleanup, [ :days ] => :environment do |_t, args|
    days = (args[:days] || 30).to_i
    cutoff_date = days.days.ago

    puts "Cleaning up events archived before #{cutoff_date.strftime('%Y-%m-%d')}..."

    old_events = ExternalEvent.where("archived_at < ?", cutoff_date)
    count = old_events.count

    if count > 0
      old_events.delete_all
      puts "✓ Deleted #{count} old archived events"
    else
      puts "No old events to clean up"
    end
  end

  desc "Archive past events (older than 7 days)"
  task archive_old: :environment do
    cutoff_date = 7.days.ago
    old_events = ExternalEvent.active.where("start_time < ?", cutoff_date)
    count = old_events.count

    if count > 0
      old_events.update_all(archived_at: Time.current)
      puts "✓ Archived #{count} past events"
    else
      puts "No past events to archive"
    end
  end

  desc "Show feed health status"
  task health: :environment do
    puts "\n" + "=" * 60
    puts "FEED HEALTH STATUS"
    puts "=" * 60

    all_healthy = true

    EventFeed.all.order(:name).each do |feed|
      puts "\n#{feed.name}:"

      # Check if active
      if !feed.active?
        puts "  ⚠️  Status: INACTIVE"
        all_healthy = false
      else
        puts "  ✓  Status: Active"
      end

      # Check last fetch time
      if feed.last_fetched_at.nil?
        puts "  ⚠️  Never fetched"
        all_healthy = false
      elsif feed.last_fetched_at < 12.hours.ago
        puts "  ⚠️  Last fetch: #{feed.last_fetched_at.strftime('%Y-%m-%d %H:%M:%S')} (stale)"
        all_healthy = false
      else
        puts "  ✓  Last fetch: #{feed.last_fetched_at.strftime('%Y-%m-%d %H:%M:%S')}"
      end

      # Check for errors
      if feed.last_error.present?
        puts "  ✗  Error: #{feed.last_error}"
        all_healthy = false
      else
        puts "  ✓  No errors"
      end

      # Check event count
      if feed.event_count == 0
        puts "  ⚠️  Event count: 0"
        all_healthy = false
      else
        puts "  ✓  Event count: #{feed.event_count}"
      end
    end

    puts "\n" + "=" * 60
    if all_healthy
      puts "✓ All feeds are healthy!"
    else
      puts "⚠️  Some feeds have issues. Run 'rake events:fetch' to retry."
    end
    puts "=" * 60 + "\n"
  end

  desc "Reprocess events from raw feed data (useful after parser fixes)"
  task :reprocess, [ :feed_id ] => :environment do |_t, args|
    feed_id = args[:feed_id]&.to_i

    if feed_id
      feed = EventFeed.find(feed_id)
      puts "Reprocessing events from: #{feed.name}"
    else
      puts "Reprocessing all events with raw data..."
    end

    puts "=" * 60

    result = ExternalEvent.reprocess_all(feed_id: feed_id)

    puts "\nReprocessing Complete!"
    puts "  Successful: #{result[:successful]}"
    puts "  Failed: #{result[:failed]}"
    puts "  Total: #{result[:total]}"
    puts "=" * 60 + "\n"
  end

  desc "List all available event rake tasks"
  task :help do
    puts "\n" + "=" * 60
    puts "EVENTS RAKE TASKS"
    puts "=" * 60
    puts "\nAvailable tasks:"
    puts "  rake events:fetch              - Fetch and sync all RSS feeds"
    puts "  rake events:summary            - Show detailed event statistics"
    puts "  rake events:upcoming[days]     - Show upcoming events (default: 7 days)"
    puts "  rake events:health             - Check feed health status"
    puts "  rake events:archive_old        - Archive events older than 7 days"
    puts "  rake events:cleanup[days]      - Delete archived events (default: 30 days)"
    puts "  rake events:reprocess[feed_id] - Reprocess events from raw data (after parser fixes)"
    puts "  rake events:help               - Show this help message"
    puts "\nExamples:"
    puts "  rake events:fetch              # Refresh all feeds"
    puts "  rake events:summary            # Show complete summary"
    puts "  rake events:upcoming[14]       # Show next 14 days of events"
    puts "  rake events:cleanup[60]        # Delete events archived 60+ days ago"
    puts "  rake events:reprocess          # Reprocess all events"
    puts "  rake events:reprocess[1]       # Reprocess events from feed ID 1"
    puts "=" * 60 + "\n"
  end
end

# Default task shows help
desc "Show events help"
task events: "events:help"
