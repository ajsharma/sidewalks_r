# frozen_string_literal: true

require "capybara/rspec"

# Capybara configuration for system tests
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1400")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Configure Capybara timeouts
Capybara.default_max_wait_time = 5
Capybara.server_host = "localhost"
Capybara.server_port = 3001
Capybara.app_host = "http://localhost:3001"

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_chrome
  end
end
