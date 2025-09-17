namespace :scheduling do
  desc "Test the activity scheduling system for a user (usage: rake scheduling:test EMAIL=user@example.com)"
  task test: :environment do
    email = ENV["EMAIL"]

    if email.blank?
      puts "Please provide an email: rake scheduling:test EMAIL=user@example.com"
      exit 1
    end

    user = User.find_by(email: email)
    if user.nil?
      puts "User with email #{email} not found"
      exit 1
    end

    puts "Testing activity scheduling for #{user.name} (#{user.email})..."
    puts

    # Initialize scheduling service
    service = ActivitySchedulingService.new(user)

    # Test dry run
    puts "=== DRY RUN TEST ==="
    puts "Activities to schedule: #{user.activities.active.count}"
    puts

    suggestions = service.suggest_schedule
    puts "Generated #{suggestions.count} scheduling suggestions:"
    puts

    suggestions.group_by { |s| s[:start_time].to_date }.each do |date, day_suggestions|
      puts "#{date.strftime('%A, %B %d, %Y')}:"
      day_suggestions.each do |suggestion|
        puts "  #{suggestion[:start_time].strftime('%I:%M %p')} - #{suggestion[:end_time].strftime('%I:%M %p')}"
        puts "  #{suggestion[:title]} (#{suggestion[:type]}, #{suggestion[:confidence]} confidence)"
        puts "  #{suggestion[:activity].name}"
        puts
      end
    end

    # Test dry run results
    puts "=== DRY RUN RESULTS ==="
    dry_run_results = service.create_calendar_events(suggestions, dry_run: true)
    puts "Total suggestions: #{dry_run_results[:total_suggestions]}"
    puts "By type: #{dry_run_results[:suggestions_by_type]}"
    puts "Existing calendar events: #{dry_run_results[:existing_events_count] || 0}"
    puts "Conflicts avoided: #{dry_run_results[:conflicts_avoided] || 0}"
    puts

    if dry_run_results[:existing_events_count] > 0
      puts "=== CONFLICT DETECTION ==="
      puts "✓ Successfully loaded existing calendar events"
      puts "✓ Conflict detection is working"
      if dry_run_results[:conflicts_avoided] > 0
        puts "✓ Automatically rescheduled conflicting activities"
      end
      puts
    else
      puts "ℹ No existing calendar events found (or Google Calendar not connected)"
      puts
    end

    puts "✓ Activity scheduling system test completed successfully"
  end

  desc "Generate sample scheduling report for all users"
  task sample_report: :environment do
    puts "=== SCHEDULING SYSTEM SAMPLE REPORT ==="
    puts

    total_users = User.active.count
    total_activities = Activity.active.count
    puts "System Overview:"
    puts "- Users: #{total_users}"
    puts "- Active Activities: #{total_activities}"
    puts

    if total_users > 0
      sample_user = User.active.joins(:activities).first
      if sample_user
        puts "Sample Schedule Generation (#{sample_user.name}):"
        service = ActivitySchedulingService.new(sample_user)
        suggestions = service.suggest_schedule

        by_type = suggestions.group_by { |s| s[:type] }
        puts "- Strict activities: #{by_type['strict']&.count || 0}"
        puts "- Flexible activities: #{by_type['flexible']&.count || 0}"
        puts "- Deadline activities: #{by_type['deadline']&.count || 0}"
        puts "- Total suggestions: #{suggestions.count}"
        puts

        if suggestions.any?
          puts "Next 3 suggested events:"
          suggestions.first(3).each_with_index do |suggestion, index|
            puts "#{index + 1}. #{suggestion[:title]}"
            puts "   #{suggestion[:start_time].strftime('%B %d at %I:%M %p')} (#{suggestion[:type]})"
          end
        end
      else
        puts "No users with activities found for sample generation"
      end
    else
      puts "No users found in system"
    end

    puts
    puts "✓ Sample report completed"
  end
end
