require "test_helper"

class ActivitiesHelperTest < ActionView::TestCase
  test "schedule_type_options returns correct options" do
    options = schedule_type_options

    assert_equal 4, options.size
    assert_includes options, [ "Flexible - Can be done anytime", "flexible" ]
    assert_includes options, [ "Strict - Specific date and time", "strict" ]
    assert_includes options, [ "Deadline - Must be done before a certain date", "deadline" ]
    assert_includes options, [ "Recurring - Repeats on a schedule", "recurring_strict" ]
  end

  test "max_frequency_options returns correct options" do
    options = max_frequency_options

    assert_equal 7, options.size
    assert_includes options, [ "Daily", 1 ]
    assert_includes options, [ "Monthly", 30 ]
    assert_includes options, [ "Every 2 months", 60 ]
    assert_includes options, [ "Every 3 months", 90 ]
    assert_includes options, [ "Every 6 months", 180 ]
    assert_includes options, [ "Yearly", 365 ]
    assert_includes options, [ "Never repeat", nil ]
  end

  test "schedule_type_options has correct structure" do
    options = schedule_type_options
    options.each do |option|
      assert_equal 2, option.size
      assert_instance_of String, option[0]
      assert_instance_of String, option[1]
    end
  end

  test "max_frequency_options has correct structure" do
    options = max_frequency_options
    options.each do |option|
      assert_equal 2, option.size
      assert_instance_of String, option[0]
      assert(option[1].is_a?(Integer) || option[1].nil?)
    end
  end
end
