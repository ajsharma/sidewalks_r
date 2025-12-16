# frozen_string_literal: true

require "capybara/rspec"

# Capybara configuration for system tests

# Default driver: rack_test (fast, no JavaScript)
# Use for most system tests that don't need JavaScript
Capybara.register_driver :rack_test do |app|
  Capybara::RackTest::Driver.new(app, headers: { 'HTTP_USER_AGENT' => 'Capybara' })
end

# JavaScript-enabled driver: headless_chrome (slower, but supports JavaScript)
# Use only when testing JavaScript functionality
# Requires chromedriver: brew install --cask chromedriver
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  # Headless mode for CI/test environments
  options.add_argument("--headless=new")  # Use new headless mode
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1400")

  # Performance optimizations
  options.add_argument("--disable-software-rasterizer")
  options.add_argument("--disable-extensions")

  # Prevent timeout issues
  options.add_argument("--dns-prefetch-disable")
  options.add_argument("--disable-features=VizDisplayCompositor")

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options,
    timeout: 30  # Increase timeout for slow connections
  )
end

# Configure Capybara
Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }  # Use Puma quietly

RSpec.configure do |config|
  # Use rack_test by default (fast, no JavaScript)
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  # Use headless_chrome only for tests tagged with :js
  config.before(:each, :js, type: :system) do
    driven_by :headless_chrome
  end
end
