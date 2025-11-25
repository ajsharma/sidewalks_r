# This file is copied to spec/ when you run 'rails generate rspec:install'

# SimpleCov configuration - must be loaded before anything else
require "simplecov"
SimpleCov.start "rails" do
  # This is typically useful for ERB. Set ERB#filename= to
  # make it possible for SimpleCov to trace the original .erb source file.
  enable_coverage_for_eval

  # Basic filters
  add_filter "/test/"
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_filter "/db/"

  # Skip complex external service integrations that require extensive infrastructure
  add_filter "/app/controllers/users/"  # Devise-generated OAuth controllers
  add_filter "/app/controllers/activity_scheduling_controller.rb"  # Complex Google API integration

  # Groups for better organization
  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  add_group "Helpers", "app/helpers"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"

  # Coverage requirement for all tests
  minimum_coverage 80

  track_files "app/**/*.rb"
end

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Require Capybara for system specs
require 'capybara/rspec'

# VCR configuration for testing external APIs
require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock

  # Filter sensitive data from recordings
  config.filter_sensitive_data("<GOOGLE_ACCESS_TOKEN>") { ENV["GOOGLE_ACCESS_TOKEN"] }
  config.filter_sensitive_data("<GOOGLE_REFRESH_TOKEN>") { ENV["GOOGLE_REFRESH_TOKEN"] }
  config.filter_sensitive_data("<GOOGLE_CLIENT_ID>") { ENV["GOOGLE_CLIENT_ID"] }
  config.filter_sensitive_data("<GOOGLE_CLIENT_SECRET>") { ENV["GOOGLE_CLIENT_SECRET"] }
  config.filter_sensitive_data("<ANTHROPIC_API_KEY>") { ENV["ANTHROPIC_API_KEY"] }

  # Allow localhost connections for Rails
  config.ignore_localhost = true

  # Configure cassette options
  config.default_cassette_options = {
    record: :once,
    allow_unused_http_interactions: false
  }

  # Allow HTTP connections when no cassette is in use for development
  config.allow_http_connections_when_no_cassette = true

  # Ignore OAuth token refresh requests in tests unless specifically testing
  config.ignore_request do |request|
    request.uri.include?("oauth2.googleapis.com/token") && !VCR.current_cassette
  end
end

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('test/fixtures')  # Keep using existing fixtures
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Make fixtures available in all examples
  config.global_fixtures = :all

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/7-1/rspec-rails
  #
  # You can also this infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Include FactoryBot syntax methods
  config.include FactoryBot::Syntax::Methods

  # Include Devise test helpers
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :system

  # Include ActiveSupport time helpers (for travel_to, etc.)
  config.include ActiveSupport::Testing::TimeHelpers
end

# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Capybara configuration for system specs
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--disable-gpu")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,1400")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_driver = :headless_chrome
Capybara.javascript_driver = :headless_chrome
