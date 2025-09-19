require "application_system_test_case"

class HealthTest < ApplicationSystemTestCase
  test "visiting the health page renders JSON" do
    visit health_url
    assert_text "status"
    assert_text "healthy"
  end
end
