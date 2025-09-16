class UserOnboardingService
  def self.populate_starter_content(user)
    return if user.activities.exists? || user.playlists.exists?

    Rails.logger.info "Populating starter content for user #{user.id} (#{user.email})"

    begin
      onboarding_data = load_onboarding_data
      created_activities = create_activities(user, onboarding_data['activities'])
      create_playlists(user, onboarding_data['playlists'], created_activities)

      Rails.logger.info "Successfully created #{created_activities.size} activities and #{onboarding_data['playlists'].size} playlists for user #{user.id}"
    rescue StandardError => e
      Rails.logger.error "Failed to populate starter content for user #{user.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  private

  def self.load_onboarding_data
    yaml_path = Rails.root.join('config', 'onboarding', 'activities.yml')
    YAML.load_file(yaml_path)
  end

  def self.create_activities(user, activities_data)
    created_activities = {}

    activities_data.each do |activity_data|
      activity = user.activities.create!(
        name: activity_data['name'],
        description: activity_data['description'],
        schedule_type: activity_data['schedule_type'],
        start_time: parse_datetime(activity_data['start_time']),
        end_time: parse_datetime(activity_data['end_time']),
        deadline: parse_datetime(activity_data['deadline']),
        max_frequency_days: activity_data['max_frequency_days'],
        activity_links: activity_data['activity_links'] || []
      )

      created_activities[activity_data['name']] = activity
    end

    created_activities
  end

  def self.create_playlists(user, playlists_data, created_activities)
    playlists_data.each do |playlist_data|
      playlist = user.playlists.create!(
        name: playlist_data['name'],
        description: playlist_data['description']
      )

      playlist_data['activities']&.each_with_index do |activity_name, index|
        activity = created_activities[activity_name]
        next unless activity

        # Create playlist_activity directly to avoid class loading issues
        position = index + 1
        PlaylistActivity.create!(
          playlist: playlist,
          activity_id: activity.id,
          position: position
        )
      end
    end
  end

  def self.parse_datetime(datetime_string)
    return nil if datetime_string.blank?

    # Handle relative dates like "+1.day 10:00" or "+5.days 17:00"
    if datetime_string.start_with?('+')
      parse_relative_datetime(datetime_string)
    else
      Time.zone.parse(datetime_string)
    end
  rescue ArgumentError => e
    Rails.logger.warn "Failed to parse datetime '#{datetime_string}': #{e.message}"
    nil
  end

  def self.parse_relative_datetime(relative_string)
    # Parse strings like "+1.day 10:00" or "+5.days 17:00"
    match = relative_string.match(/\+(\d+)\.(day|days)\s+(\d{1,2}):(\d{2})/)
    return nil unless match

    days = match[1].to_i
    hour = match[3].to_i
    minute = match[4].to_i

    Time.zone.now.beginning_of_day + days.days + hour.hours + minute.minutes
  rescue StandardError => e
    Rails.logger.warn "Failed to parse relative datetime '#{relative_string}': #{e.message}"
    nil
  end
end
