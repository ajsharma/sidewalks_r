# Mark existing migrations as safe
StrongMigrations.start_after = 20241201000000

# Set migration timeout
StrongMigrations.lock_timeout = 10.seconds

# Check for index corruption
StrongMigrations.check_down = true

# Target version (adjust based on your production environment)
StrongMigrations.target_version = 15

# Development and test environments are typically safer for experimental migrations
StrongMigrations.enable_check(:remove_column, :add_index) unless Rails.env.development? || Rails.env.test?
