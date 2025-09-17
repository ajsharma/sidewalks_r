# Service for scheduling activities and generating calendar agendas.
# Integrates with Google Calendar API to propose and create events.
class ActivitySchedulingService
  # Represents a Google Calendar
  CalendarInfo = Data.define(
    :id,
    :summary,
    :description,
    :primary,
    :access_role
  ) do
    # @param calendar [Google::Apis::CalendarV3::CalendarListEntry] calendar from Google API
    # @return [CalendarInfo] new calendar info data object
    def self.from_api(calendar)
      new(
        id: calendar.id,
        summary: calendar.summary,
        description: calendar.description,
        primary: calendar.primary || false,
        access_role: calendar.access_role
      )
    end
  end

  # Represents scheduling timeline item
  TimelineItem = Data.define(
    :activity_name,
    :title,
    :start_time,
    :end_time,
    :type,
    :confidence,
    :notes
  )

  # Represents dry run scheduling results
  DryRunResults = Data.define(
    :total_suggestions,
    :suggestions_by_type,
    :existing_events_count,
    :conflicts_avoided,
    :timeline,
    :next_steps
  )

  # Represents agenda summary statistics
  AgendaSummary = Data.define(
    :total_suggestions,
    :total_existing,
    :total_events,
    :suggestions_by_type,
    :conflicts_avoided,
    :date_range_start,
    :date_range_end,
    :urgent_deadlines
  )

  attr_reader :user, :activities, :options

  # Initializes the service with user, activities, and options
  # @param user [User] the user for whom to schedule activities
  # @param activities [ActiveRecord::Relation, nil] activities to schedule, defaults to user's active activities
  # @param options [Hash] scheduling options to override defaults
  # @return [ActivitySchedulingService] new instance of the service
  def initialize(user, activities = nil, options = {})
    @user = user
    @activities = activities || user.activities.active
    @options = default_options.merge(options)
    @existing_events = []
    @user_timezone = user.timezone || "America/Los_Angeles"
    Rails.logger.info "ActivitySchedulingService initialized with user timezone: #{@user_timezone}"
  end

  # Generate a unified agenda containing both existing events and suggestions
  # @param date_range [Range, nil] date range for agenda, defaults to next 2 weeks
  # @return [AgendaProposal] unified agenda with existing events and activity suggestions
  def generate_agenda(date_range = nil)
    date_range ||= default_date_range

    # Fetch existing calendar events to avoid conflicts
    existing_events = load_existing_events(date_range)

    # Generate activity suggestions
    suggestions = generate_activity_suggestions(date_range, existing_events)

    # Create unified agenda proposal
    AgendaProposal.new(
      existing_events: existing_events,
      suggestions: suggestions,
      date_range: date_range,
      user_timezone: @user_timezone
    )
  end


  # Create actual calendar events (requires Google Calendar integration)
  # @param suggestions [Array<AgendaProposedEvent>, Array<Hash>] array of activity suggestion events to create events from
  # @param dry_run [Boolean] if true, returns formatted results without creating events
  # @return [ActivitySchedulingService::DryRunResults, Array<Hash>] dry run results data or array of created event results
  def create_calendar_events(suggestions, dry_run: true)
    # Handle empty suggestions array
    return format_dry_run_results([]) if suggestions.empty?

    # Handle both AgendaProposedEvent objects and raw hashes
    activity_suggestions = if suggestions.first.respond_to?(:suggested_activity?)
      # AgendaProposedEvent objects - filter only suggested activities (not existing calendar events)
      suggestions.select(&:suggested_activity?)
    else
      # Raw hash objects (for backward compatibility with tests)
      suggestions
    end

    return format_dry_run_results(activity_suggestions) if dry_run

    created_events = []
    google_service = GoogleCalendarService.new(user.active_google_account)

    activity_suggestions.each do |suggestion|
      begin
        event = google_service.create_event(
          summary: suggestion.title,
          description: suggestion.raw_data[:description],
          start_time: suggestion.start_time,
          end_time: suggestion.end_time,
          calendar_id: suggestion.raw_data[:calendar_id] || "primary"
        )

        created_events << {
          activity: suggestion.activity,
          google_event_id: event["id"],
          start_time: suggestion.start_time,
          end_time: suggestion.end_time,
          status: "created"
        }
      rescue Google::Auth::AuthorizationError, Google::Apis::ClientError => e
        Rails.logger.error "Failed to create calendar event for activity #{suggestion.activity.id}: #{e.message}"
        created_events << {
          activity: suggestion.activity,
          error: e.message,
          status: "failed"
        }
      end
    end

    created_events
  end

  # Bulk schedule activities with user confirmation
  # @param date_range [Range, nil] date range for scheduling, defaults to next 2 weeks
  # @param dry_run [Boolean] if true, returns preview without creating events
  # @return [ActivitySchedulingService::DryRunResults, Array<Hash>] dry run results data or array of created event results
  def schedule_activities(date_range = nil, dry_run: true)
    date_range ||= default_date_range
    existing_events = load_existing_events(date_range)
    suggestions = generate_activity_suggestions(date_range, existing_events)
    create_calendar_events(suggestions, dry_run: dry_run)
  end

  private

  def default_options
    {
      work_hours_start: 9,
      work_hours_end: 17,
      preferred_duration: 60.minutes,
      buffer_time: 15.minutes,
      exclude_weekends: false
    }
  end

  def default_date_range
    Date.current..(Date.current + 2.weeks)
  end

  def suggest_strict_schedule(activity, date_range)
    suggestions = []

    # Strict activities already have defined start/end times
    if activity.start_time? && activity.end_time?
      start_date = [ activity.start_time.to_date, date_range.begin ].max
      end_date = [ activity.end_time.to_date, date_range.end ].min

      if start_date <= end_date
        suggestions << {
          activity: activity,
          title: activity.name,
          description: activity.description,
          start_time: activity.start_time,
          end_time: activity.end_time,
          type: "strict",
          confidence: "high"
        }
      end
    end

    suggestions
  end

  def suggest_flexible_schedule(activity, date_range)
    suggestions = []

    # For flexible activities, suggest optimal times based on frequency
    frequency_days = activity.max_frequency_days || 7
    duration = options[:preferred_duration]

    current_date = date_range.begin
    time_offset = 0 # Stagger activities to avoid conflicts

    while current_date <= date_range.end
      # Skip weekends if configured
      if options[:exclude_weekends] && current_date.weekend?
        current_date += 1.day
        next
      end

      # Suggest different times for different activity types to reduce conflicts
      base_date = current_date.in_time_zone(@user_timezone).beginning_of_day

      suggested_time = if activity.name.downcase.include?("work") || activity.name.downcase.include?("meeting")
        base_date + options[:work_hours_start].hours + time_offset.minutes
      else
        # Personal activities - stagger between morning and evening
        base_time = if activity.name.downcase.include?("walk") || activity.name.downcase.include?("exercise")
          7.hours # 7 AM for physical activities
        else
          19.hours # 7 PM for other activities
        end

        base_date + base_time + time_offset.minutes
      end

      suggestions << {
        activity: activity,
        title: activity.name,
        description: activity.description,
        start_time: suggested_time,
        end_time: suggested_time + duration,
        type: "flexible",
        confidence: "medium",
        frequency_note: "Suggested every #{frequency_days} days"
      }

      # Move to next occurrence based on frequency
      current_date += frequency_days.days

      # Increment time offset to stagger activities (max 2 hours)
      time_offset = (time_offset + 30) % 120
    end

    suggestions
  end

  def suggest_deadline_schedule(activity, date_range)
    suggestions = []

    return suggestions unless activity.deadline?

    # Only suggest if deadline is within the date range
    if date_range.cover?(activity.deadline.to_date)
      # Suggest scheduling 1-3 days before deadline depending on urgency
      days_before = case activity.deadline - Time.current
      when 0..2.days then 0 # Do today if deadline is very soon
      when 2.days..1.week then 1 # Do 1 day before
      else 3 # Do 3 days before for longer deadlines
      end

      scheduled_date = activity.deadline.to_date - days_before.days

      if date_range.cover?(scheduled_date)
        # Schedule during work hours for work tasks, otherwise flexible
        base_date = scheduled_date.in_time_zone(@user_timezone).beginning_of_day
        suggested_time = if activity.name.downcase.include?("work") || activity.name.downcase.include?("project")
          base_date + options[:work_hours_start].hours
        else
          base_date + 14.hours # 2 PM
        end

        suggestions << {
          activity: activity,
          title: "Complete: #{activity.name}",
          description: "#{activity.description}\n\nDeadline: #{activity.deadline.strftime('%B %d, %Y at %I:%M %p')}",
          start_time: suggested_time,
          end_time: suggested_time + options[:preferred_duration],
          type: "deadline",
          confidence: "high",
          urgency: activity.expired? ? "overdue" : "upcoming",
          deadline: activity.deadline
        }
      end
    end

    suggestions
  end

  def format_dry_run_results(suggestions)
    # Handle empty suggestions array
    if suggestions.empty?
      return ActivitySchedulingService::DryRunResults.new(
        total_suggestions: 0,
        suggestions_by_type: {},
        existing_events_count: @existing_events.count,
        conflicts_avoided: 0,
        timeline: [],
        next_steps: [ "No activities to schedule in the selected date range" ]
      )
    end

    # Handle both AgendaProposedEvent objects and raw hashes
    if suggestions.first.respond_to?(:conflict_avoided?)
      # AgendaProposedEvent objects
      conflicts_avoided = @existing_events.count > 0 ? suggestions.count(&:conflict_avoided?) : 0

      timeline_items = suggestions.map do |suggestion|
        ActivitySchedulingService::TimelineItem.new(
          activity_name: suggestion.activity.name,
          title: suggestion.title,
          start_time: suggestion.start_time,
          end_time: suggestion.end_time,
          type: suggestion.type,
          confidence: suggestion.confidence,
          notes: [
            suggestion.frequency_note,
            suggestion.urgency ? "Urgency: #{suggestion.urgency}" : nil,
            suggestion.conflict_avoided? ? "Rescheduled to avoid conflict" : nil
          ].compact
        )
      end

      suggestions_by_type = suggestions.group_by(&:type).transform_values(&:count)
    else
      # Raw hash objects (for backward compatibility with tests)
      conflicts_avoided = @existing_events.count > 0 ? suggestions.count { |suggestion| suggestion[:conflict_avoided] } : 0

      timeline_items = suggestions.map do |suggestion|
        ActivitySchedulingService::TimelineItem.new(
          activity_name: suggestion[:activity].name,
          title: suggestion[:title],
          start_time: suggestion[:start_time],
          end_time: suggestion[:end_time],
          type: suggestion[:type],
          confidence: suggestion[:confidence],
          notes: [
            suggestion[:frequency_note],
            suggestion[:urgency] ? "Urgency: #{suggestion[:urgency]}" : nil,
            suggestion[:conflict_avoided] ? "Rescheduled to avoid conflict" : nil
          ].compact
        )
      end

      suggestions_by_type = suggestions.group_by { |suggestion| suggestion[:type] }.transform_values(&:count)
    end

    next_steps = [
      "Review the suggested schedule above",
      @existing_events.any? ? "Conflicts with #{@existing_events.count} existing events have been avoided" : nil,
      "Adjust date range or preferences if needed",
      "Call with dry_run: false to create actual calendar events"
    ].compact

    ActivitySchedulingService::DryRunResults.new(
      total_suggestions: suggestions.count,
      suggestions_by_type: suggestions_by_type,
      existing_events_count: @existing_events.count,
      conflicts_avoided: conflicts_avoided,
      timeline: timeline_items,
      next_steps: next_steps
    )
  end

  # Extract activity suggestion generation into separate method
  def generate_activity_suggestions(date_range, existing_events)
    suggestions = []

    activities.each do |activity|
      case activity.schedule_type
      when "strict"
        suggestions.concat(suggest_strict_schedule(activity, date_range))
      when "flexible"
        suggestions.concat(suggest_flexible_schedule(activity, date_range))
      when "deadline"
        suggestions.concat(suggest_deadline_schedule(activity, date_range))
      end
    end

    # Filter out suggestions that conflict with existing events
    filter_conflicting_suggestions(suggestions, existing_events)
  end

  def load_existing_events(date_range)
    existing_events = []

    return existing_events unless user.active_google_account.present?

    begin
      google_service = GoogleCalendarService.new(user.active_google_account)

      # Get events from all calendars
      calendars = google_service.fetch_calendars

      calendars.each do |calendar|
        events = google_service.list_events(
          calendar.fetch(:id),
          date_range.begin.beginning_of_day,
          date_range.end.end_of_day
        )

        events.each do |event|
          Rails.logger.info "Processing existing event: #{event.inspect}"

          # Skip all-day events and events without start/end times
          next unless event.start&.date_time && event.end&.date_time

          existing_events << {
            summary: event.summary || "Busy",
            start_time: event.start.date_time,
            end_time: event.end.date_time,
            calendar_id: calendar.fetch(:id),
            calendar_name: calendar.fetch(:summary)
          }
        end
      end

      Rails.logger.info "Loaded #{existing_events.count} existing calendar events for conflict detection"
    rescue Google::Auth::AuthorizationError => e
      Rails.logger.warn "Failed to load existing calendar events: #{e.message}"
      # Continue without conflict detection if calendar access fails
    end

    existing_events
  end

  def filter_conflicting_suggestions(suggestions, existing_events)
    return suggestions if existing_events.empty?

    filtered_suggestions = []

    suggestions.each do |suggestion|
      if has_conflict?(suggestion[:start_time], suggestion[:end_time], existing_events)
        # Try to reschedule flexible activities
        if suggestion[:type] == "flexible"
          rescheduled = find_alternative_time(suggestion, existing_events)
          if rescheduled
            filtered_suggestions << rescheduled
          else
            # Mark as skipped due to conflicts
            Rails.logger.info "Skipping #{suggestion[:title]} - no available time slots"
          end
        else
          # For strict/deadline activities, keep them but mark as conflicting
          suggestion[:has_conflict] = true
          suggestion[:confidence] = "low"
          suggestion[:notes] = [ suggestion[:notes], "⚠️ Conflicts with existing calendar event" ].flatten.compact
          filtered_suggestions << suggestion
        end
      else
        filtered_suggestions << suggestion
      end
    end

    # Sort by start time
    filtered_suggestions.sort_by { |suggestion| suggestion[:start_time] }
  end

  def has_conflict?(start_time, end_time, existing_events)
    existing_events.any? do |event|
      # Convert all times to the same timezone for comparison
      existing_start = event[:start_time].in_time_zone(@user_timezone)
      existing_end = event[:end_time].in_time_zone(@user_timezone)
      suggestion_start = start_time.in_time_zone(@user_timezone)
      suggestion_end = end_time.in_time_zone(@user_timezone)

      # Check for any overlap between suggested time and existing event
      suggestion_start < existing_end && suggestion_end > existing_start
    end
  end

  def find_alternative_time(original_suggestion, existing_events)
    activity = original_suggestion[:activity]
    original_start = original_suggestion[:start_time]
    duration = original_suggestion[:end_time] - original_start

    # Try different time slots throughout the day
    base_date = original_start.to_date
    time_slots = generate_time_slots(base_date)

    time_slots.each do |slot_start|
      slot_end = slot_start + duration

      # Skip if this slot conflicts with existing events
      next if has_conflict?(slot_start, slot_end, existing_events)

      # Found a free slot
      return original_suggestion.merge(
        start_time: slot_start,
        end_time: slot_end,
        conflict_avoided: true,
        confidence: "medium",
        notes: [ original_suggestion[:notes], "Rescheduled to avoid conflict" ].flatten.compact
      )
    end

    # No alternative time found
    nil
  end

  def generate_time_slots(date)
    slots = []

    base_date = date.in_time_zone(@user_timezone).beginning_of_day

    # Morning slots (7 AM - 11 AM)
    (7..10).each do |hour|
      [ 0, 30 ].each do |minute|
        slots << base_date + hour.hours + minute.minutes
      end
    end

    # Afternoon slots (1 PM - 5 PM)
    (13..16).each do |hour|
      [ 0, 30 ].each do |minute|
        slots << base_date + hour.hours + minute.minutes
      end
    end

    # Evening slots (6 PM - 9 PM)
    (18..20).each do |hour|
      [ 0, 30 ].each do |minute|
        slots << base_date + hour.hours + minute.minutes
      end
    end

    slots
  end
end
