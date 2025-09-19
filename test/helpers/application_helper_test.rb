require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "module exists" do
    assert defined?(ApplicationHelper)
    assert ApplicationHelper.is_a?(Module)
  end
end
