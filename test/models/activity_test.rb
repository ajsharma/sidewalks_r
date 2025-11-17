require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @activity = Activity.new(
      user: @user,
      name: "Test Activity",
      description: "Test description",
      schedule_type: "flexible"
    )
  end

  test "should be valid" do
    assert @activity.valid?
  end

  test "should require user" do
    @activity.user = nil
    assert_not @activity.valid?
    assert_includes @activity.errors[:user], "must exist"
  end

  test "should require name" do
    @activity.name = ""
    assert_not @activity.valid?
    assert_includes @activity.errors[:name], "can't be blank"
  end

  test "should require valid schedule_type" do
    @activity.schedule_type = "invalid"
    assert_not @activity.valid?
    assert_includes @activity.errors[:schedule_type], "is not included in the list"
  end

  test "should allow valid schedule_types" do
    Activity::SCHEDULE_TYPES.each do |type|
      @activity.schedule_type = type

      # Add required fields for specific schedule types
      case type
      when "strict"
        @activity.start_time = 1.hour.from_now
        @activity.end_time = 2.hours.from_now
      when "deadline"
        @activity.deadline = 1.week.from_now
      end

      assert @activity.valid?, "#{type} should be valid. Errors: #{@activity.errors.full_messages}"
    end
  end

  test "should validate max_frequency_days inclusion" do
    @activity.max_frequency_days = 999
    assert_not @activity.valid?
    assert_includes @activity.errors[:max_frequency_days], "is not included in the list"
  end

  test "should allow valid max_frequency_days" do
    Activity::MAX_FREQUENCY_OPTIONS.each do |option|
      @activity.max_frequency_days = option
      assert @activity.valid?, "#{option} should be valid"
    end
  end

  test "should generate slug from name" do
    @activity.save!
    assert_equal "test-activity", @activity.slug
  end

  test "should generate unique slug when name conflicts" do
    @activity.save!
    activity2 = Activity.create!(
      user: @user,
      name: "Test Activity",
      schedule_type: "flexible"
    )
    assert_equal "test-activity-1", activity2.slug
  end

  test "should use to_param as slug" do
    @activity.save!
    assert_equal @activity.slug, @activity.to_param
  end

  test "archived? should return false when not archived" do
    assert_not @activity.archived?
  end

  test "archived? should return true when archived" do
    @activity.archived_at = Time.current
    assert @activity.archived?
  end

  test "archive! should set archived_at" do
    @activity.save!
    assert_nil @activity.archived_at
    @activity.archive!
    assert_not_nil @activity.archived_at
  end

  test "strict_schedule? should return true for strict activities" do
    @activity.schedule_type = "strict"
    assert @activity.strict_schedule?
  end

  test "flexible_schedule? should return true for flexible activities" do
    @activity.schedule_type = "flexible"
    assert @activity.flexible_schedule?
  end

  test "deadline_based? should return true for deadline activities" do
    @activity.schedule_type = "deadline"
    assert @activity.deadline_based?
  end

  test "has_deadline? should return true when deadline is set" do
    @activity.deadline = Time.current + 1.day
    assert @activity.has_deadline?
  end

  test "has_deadline? should return false when deadline is nil" do
    @activity.deadline = nil
    assert_not @activity.has_deadline?
  end

  test "expired? should return true when deadline has passed" do
    @activity.deadline = Time.current - 1.day
    assert @activity.expired?
  end

  test "expired? should return false when deadline is in future" do
    @activity.deadline = Time.current + 1.day
    assert_not @activity.expired?
  end

  test "expired? should return false when no deadline" do
    @activity.deadline = nil
    assert_not @activity.expired?
  end

  test "activity_links should parse JSON links" do
    @activity.links = '[{"url": "https://example.com", "title": "Example"}]'
    expected = [ { "url" => "https://example.com", "title" => "Example" } ]
    assert_equal expected, @activity.activity_links
  end

  test "activity_links should return empty array for invalid JSON" do
    @activity.links = "invalid json"
    assert_equal [], @activity.activity_links
  end

  test "activity_links should return empty array when links is nil" do
    @activity.links = nil
    assert_equal [], @activity.activity_links
  end

  test "activity_links= should store links as JSON" do
    links = [ { "url" => "https://example.com", "title" => "Example" } ]
    @activity.activity_links = links
    assert_equal links.to_json, @activity.links
  end

  test "max_frequency_description should return correct descriptions" do
    descriptions = {
      1 => "Daily",
      30 => "Monthly",
      60 => "Every 2 months",
      90 => "Every 3 months",
      180 => "Every 6 months",
      365 => "Yearly",
      nil => "Never repeat",
      45 => "Every 45 days"
    }

    descriptions.each do |days, expected|
      @activity.max_frequency_days = days
      assert_equal expected, @activity.max_frequency_description
    end
  end

  # AI-related tests
  test "ai_generated? should return true when ai_generated is true" do
    activity = activities(:ai_generated)
    assert activity.ai_generated?
  end

  test "ai_generated? should return false when ai_generated is false" do
    activity = activities(:one)
    assert_not activity.ai_generated?
  end

  test "formatted_suggested_months should return month names" do
    activity = activities(:ai_generated)
    assert_equal "May, June, July, August, September", activity.formatted_suggested_months
  end

  test "formatted_suggested_months should return 'Any time' when empty" do
    activity = activities(:one)
    assert_equal "Any time", activity.formatted_suggested_months
  end

  test "formatted_suggested_days should return day names" do
    activity = activities(:ai_generated)
    assert_equal "Sunday, Saturday", activity.formatted_suggested_days
  end

  test "formatted_suggested_days should return 'Any day' when empty" do
    activity = activities(:one)
    assert_equal "Any day", activity.formatted_suggested_days
  end

  test "formatted_time_of_day should return titleized time" do
    activity = activities(:ai_generated)
    assert_equal "Morning", activity.formatted_time_of_day
  end

  test "formatted_time_of_day should return 'Flexible' when nil" do
    activity = activities(:one)
    assert_equal "Flexible", activity.formatted_time_of_day
  end

  test "has_many ai_suggestions association" do
    activity = activities(:one)
    suggestion = ai_activity_suggestions(:text_completed)
    suggestion.update!(final_activity: activity, accepted: true)

    assert_includes activity.ai_suggestions, suggestion
  end

  test "originating_suggestion should return accepted suggestion" do
    activity = activities(:one)
    suggestion = ai_activity_suggestions(:text_completed)
    suggestion.update!(final_activity: activity, accepted: true)

    assert_equal suggestion, activity.originating_suggestion
  end

  # Phase 1: Recurring events and duration fields
  test "should allow recurring_strict schedule type" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO" ] }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.parse("18:00")
    @activity.occurrence_time_end = Time.parse("19:00")

    assert @activity.valid?, "recurring_strict should be valid. Errors: #{@activity.errors.full_messages}"
  end

  test "should store recurrence_rule as jsonb" do
    recurrence_rule = { "freq" => "MONTHLY", "interval" => 1, "byday" => [ "SU" ], "bysetpos" => [ 1 ] }
    @activity.recurrence_rule = recurrence_rule
    @activity.save!

    @activity.reload
    assert_equal recurrence_rule, @activity.recurrence_rule
  end

  test "should store recurrence dates" do
    start_date = Date.current
    end_date = 3.months.from_now.to_date

    @activity.recurrence_start_date = start_date
    @activity.recurrence_end_date = end_date
    @activity.save!

    @activity.reload
    assert_equal start_date, @activity.recurrence_start_date
    assert_equal end_date, @activity.recurrence_end_date
  end

  test "should store occurrence times" do
    # Use Time.zone.parse to get times in the application's timezone
    start_time = Time.zone.parse("09:00")
    end_time = Time.zone.parse("12:00")

    @activity.occurrence_time_start = start_time
    @activity.occurrence_time_end = end_time
    @activity.save!

    @activity.reload
    # Compare just the time component (hour, minute, second)
    assert_equal "09:00:00", @activity.occurrence_time_start.strftime("%H:%M:%S")
    assert_equal "12:00:00", @activity.occurrence_time_end.strftime("%H:%M:%S")
  end

  test "should store duration_minutes" do
    @activity.duration_minutes = 120
    @activity.save!

    @activity.reload
    assert_equal 120, @activity.duration_minutes
  end

  test "should allow nil duration_minutes" do
    @activity.duration_minutes = nil
    assert @activity.valid?
  end
end
