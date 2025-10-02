require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # TODO: Add accessibility testing with axe-core integration
  # The axe-core-capybara gem is installed and available for future implementation
  # Consider implementing custom accessibility assertions or using alternative gem
end
