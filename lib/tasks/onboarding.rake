namespace :onboarding do
  desc "Test the onboarding system by loading the YAML data"
  task test: :environment do
    puts "Testing onboarding YAML file..."

    begin
      yaml_path = Rails.root.join("config", "onboarding", "san_francisco.yml")
      data = YAML.load_file(yaml_path)

      puts "✓ YAML file loaded successfully"
      puts "  Activities: #{data['activities']&.size || 0}"
      puts "  Playlists: #{data['playlists']&.size || 0}"

      # Test date parsing
      puts "\nTesting date parsing..."
      test_dates = [ "+1.day 10:00", "+5.days 17:00", "+90.days 23:59" ]
      test_dates.each do |date_str|
        parsed = UserOnboardingService.send(:parse_datetime, date_str)
        puts "  #{date_str} -> #{parsed}"
      end

      puts "\n✓ Onboarding system test completed successfully"
    rescue StandardError => e
      puts "✗ Error: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end

  desc "Populate starter content for a specific user (usage: rake onboarding:populate_user EMAIL=user@example.com)"
  task populate_user: :environment do
    email = ENV["EMAIL"]

    if email.blank?
      puts "Please provide an email: rake onboarding:populate_user EMAIL=user@example.com"
      exit 1
    end

    user = User.find_by(email: email)
    if user.nil?
      puts "User with email #{email} not found"
      exit 1
    end

    puts "Populating starter content for #{user.name} (#{user.email})..."
    UserOnboardingService.populate_starter_content(user)
    puts "Done!"
  end
end
