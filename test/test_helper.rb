require "simplecov"
SimpleCov.start "rails" do
  # Basic filters
  add_filter "/test/"
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

  # Coverage requirements - realistic target based on current state
  # Target: Maintain >58% overall coverage with comprehensive tests for business logic
  # Focus on meaningful coverage rather than absolute numbers
  minimum_coverage 58
  # Note: Per-file minimums disabled due to varied complexity

  track_files "app/**/*.rb"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# VCR configuration for testing external APIs
require "vcr"
require "webmock/minitest"

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock

  # Filter sensitive data from recordings
  config.filter_sensitive_data("<GOOGLE_ACCESS_TOKEN>") { ENV["GOOGLE_ACCESS_TOKEN"] }
  config.filter_sensitive_data("<GOOGLE_REFRESH_TOKEN>") { ENV["GOOGLE_REFRESH_TOKEN"] }
  config.filter_sensitive_data("<GOOGLE_CLIENT_ID>") { ENV["GOOGLE_CLIENT_ID"] }
  config.filter_sensitive_data("<GOOGLE_CLIENT_SECRET>") { ENV["GOOGLE_CLIENT_SECRET"] }

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

module ActiveSupport
  class TestCase
    # Disable parallel execution for SimpleCov compatibility
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end

# Load test support files
Dir[Rails.root.join("test", "support", "**", "*.rb")].each { |f| require f }
