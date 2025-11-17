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
      when "recurring_strict"
        @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO" ] }
        @activity.recurrence_start_date = Date.current
        @activity.occurrence_time_start = Time.zone.parse("18:00")
        @activity.occurrence_time_end = Time.zone.parse("19:00")
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

  # Phase 2: Validation tests

  test "recurring_strict requires recurrence_rule" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    assert_not @activity.valid?
    assert_includes @activity.errors[:recurrence_rule], "is required for recurring events"
  end

  test "recurring_strict requires recurrence_start_date" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1 }
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    assert_not @activity.valid?
    assert_includes @activity.errors[:recurrence_start_date], "is required for recurring events"
  end

  test "recurring_strict requires occurrence_time_start" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    assert_not @activity.valid?
    assert_includes @activity.errors[:occurrence_time_start], "is required for recurring events"
  end

  test "recurring_strict requires occurrence_time_end" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.zone.parse("09:00")

    assert_not @activity.valid?
    assert_includes @activity.errors[:occurrence_time_end], "is required for recurring events"
  end

  test "occurrence_time_end must be after occurrence_time_start" do
    @activity.occurrence_time_start = Time.zone.parse("10:00")
    @activity.occurrence_time_end = Time.zone.parse("09:00")

    assert_not @activity.valid?
    assert_includes @activity.errors[:occurrence_time_end], "must be after start time"
  end

  test "occurrence_time_end cannot equal occurrence_time_start" do
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("09:00")

    assert_not @activity.valid?
    assert_includes @activity.errors[:occurrence_time_end], "must be after start time"
  end

  test "recurrence_rule must have valid frequency" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "INVALID" }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    assert_not @activity.valid?
    assert_includes @activity.errors[:recurrence_rule], "must have valid freq: DAILY, WEEKLY, MONTHLY, YEARLY"
  end

  test "duration_minutes must be greater than 0" do
    @activity.duration_minutes = 0

    assert_not @activity.valid?
    assert_includes @activity.errors[:duration_minutes], "must be greater than 0"
  end

  test "duration_minutes must be greater than 0 when negative" do
    @activity.duration_minutes = -10

    assert_not @activity.valid?
    assert_includes @activity.errors[:duration_minutes], "must be greater than 0"
  end

  test "duration_minutes cannot exceed 720 minutes" do
    @activity.duration_minutes = 721

    assert_not @activity.valid?
    assert_includes @activity.errors[:duration_minutes], "cannot exceed 720 minutes (12 hours)"
  end

  test "duration_minutes allows 720 minutes" do
    @activity.duration_minutes = 720
    assert @activity.valid?
  end

  # Phase 2: Duration helper tests

  test "effective_duration_minutes returns duration_minutes when set" do
    @activity.duration_minutes = 90
    assert_equal 90, @activity.effective_duration_minutes
  end

  test "effective_duration_minutes returns occurrence_duration_minutes for recurring_strict" do
    @activity.schedule_type = "recurring_strict"
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("11:30")

    assert_equal 150, @activity.effective_duration_minutes
  end

  test "effective_duration_minutes returns calculated_duration_minutes for strict" do
    @activity.schedule_type = "strict"
    @activity.start_time = Time.current
    @activity.end_time = Time.current + 2.hours

    assert_equal 120, @activity.effective_duration_minutes
  end

  test "effective_duration_minutes returns 60 as default" do
    @activity.schedule_type = "flexible"
    assert_equal 60, @activity.effective_duration_minutes
  end

  test "occurrence_duration_minutes calculates from occurrence times" do
    @activity.occurrence_time_start = Time.zone.parse("14:00")
    @activity.occurrence_time_end = Time.zone.parse("16:30")

    assert_equal 150, @activity.occurrence_duration_minutes
  end

  test "occurrence_duration_minutes returns nil when times not set" do
    assert_nil @activity.occurrence_duration_minutes
  end

  test "calculated_duration_minutes calculates from start and end times" do
    @activity.start_time = Time.current
    @activity.end_time = Time.current + 3.hours

    assert_equal 180, @activity.calculated_duration_minutes
  end

  test "calculated_duration_minutes returns nil when times not set" do
    assert_nil @activity.calculated_duration_minutes
  end

  test "time_windowed? returns true for strict activity with shorter duration" do
    @activity.schedule_type = "strict"
    @activity.start_time = Time.current
    @activity.end_time = Time.current + 3.hours
    @activity.duration_minutes = 120

    assert @activity.time_windowed?
  end

  test "time_windowed? returns false for strict activity with matching duration" do
    @activity.schedule_type = "strict"
    @activity.start_time = Time.current
    @activity.end_time = Time.current + 2.hours
    @activity.duration_minutes = 120

    assert_not @activity.time_windowed?
  end

  test "time_windowed? returns true for recurring_strict with shorter duration" do
    @activity.schedule_type = "recurring_strict"
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("12:00")
    @activity.duration_minutes = 120

    assert @activity.time_windowed?
  end

  test "time_windowed? returns false for flexible activity" do
    @activity.schedule_type = "flexible"
    @activity.duration_minutes = 60

    assert_not @activity.time_windowed?
  end

  test "time_window returns details for strict time-windowed activity" do
    start = Time.current
    finish = start + 3.hours
    @activity.schedule_type = "strict"
    @activity.start_time = start
    @activity.end_time = finish
    @activity.duration_minutes = 120

    window = @activity.time_window
    assert_equal start, window[:start]
    assert_equal finish, window[:end]
    assert_equal 180, window[:duration]
    assert_equal 120, window[:attendance_duration]
  end

  test "time_window returns details for recurring_strict time-windowed activity" do
    start_time = Time.zone.parse("09:00")
    end_time = Time.zone.parse("12:00")
    @activity.schedule_type = "recurring_strict"
    @activity.occurrence_time_start = start_time
    @activity.occurrence_time_end = end_time
    @activity.duration_minutes = 120

    window = @activity.time_window
    # Compare just the hour and minute since occurrence times don't have date context
    assert_equal start_time.hour, window[:start].hour
    assert_equal start_time.min, window[:start].min
    assert_equal end_time.hour, window[:end].hour
    assert_equal end_time.min, window[:end].min
    assert_equal 180, window[:duration]
    assert_equal 120, window[:attendance_duration]
  end

  test "time_window returns nil for non-windowed activity" do
    @activity.schedule_type = "flexible"
    assert_nil @activity.time_window
  end

  # Phase 2: Recurrence helper tests

  test "recurring_strict? returns true for recurring_strict activities" do
    @activity.schedule_type = "recurring_strict"
    assert @activity.recurring_strict?
  end

  test "recurring_strict? returns false for other schedule types" do
    @activity.schedule_type = "flexible"
    assert_not @activity.recurring_strict?
  end

  test "matches_recurrence_pattern? returns false for non-recurring activities" do
    @activity.schedule_type = "flexible"
    assert_not @activity.matches_recurrence_pattern?(Date.current)
  end

  test "matches_recurrence_pattern? matches daily pattern" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current

    assert @activity.matches_recurrence_pattern?(Date.current)
    assert @activity.matches_recurrence_pattern?(Date.current + 1.day)
    assert @activity.matches_recurrence_pattern?(Date.current + 2.days)
  end

  test "matches_recurrence_pattern? matches daily pattern with interval" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 2 }
    @activity.recurrence_start_date = Date.current

    assert @activity.matches_recurrence_pattern?(Date.current)
    assert_not @activity.matches_recurrence_pattern?(Date.current + 1.day)
    assert @activity.matches_recurrence_pattern?(Date.current + 2.days)
  end

  test "matches_recurrence_pattern? matches weekly pattern" do
    # Start on a Monday
    monday = Date.current.beginning_of_week
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO" ] }
    @activity.recurrence_start_date = monday

    assert @activity.matches_recurrence_pattern?(monday)
    assert @activity.matches_recurrence_pattern?(monday + 1.week)
    assert_not @activity.matches_recurrence_pattern?(monday + 1.day)
  end

  test "matches_recurrence_pattern? matches weekly pattern with multiple days" do
    monday = Date.current.beginning_of_week
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO", "WE", "FR" ] }
    @activity.recurrence_start_date = monday

    assert @activity.matches_recurrence_pattern?(monday) # Monday
    assert_not @activity.matches_recurrence_pattern?(monday + 1.day) # Tuesday
    assert @activity.matches_recurrence_pattern?(monday + 2.days) # Wednesday
    assert_not @activity.matches_recurrence_pattern?(monday + 3.days) # Thursday
    assert @activity.matches_recurrence_pattern?(monday + 4.days) # Friday
  end

  test "matches_recurrence_pattern? matches monthly pattern by monthday" do
    first_of_month = Date.current.beginning_of_month
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "MONTHLY", "interval" => 1, "bymonthday" => [ 15 ] }
    @activity.recurrence_start_date = first_of_month

    assert @activity.matches_recurrence_pattern?(first_of_month + 14.days) # 15th
    assert_not @activity.matches_recurrence_pattern?(first_of_month + 13.days) # 14th
    assert_not @activity.matches_recurrence_pattern?(first_of_month + 15.days) # 16th
  end

  test "matches_recurrence_pattern? matches monthly pattern by position - first Sunday" do
    # Find first Sunday of current month
    first_of_month = Date.current.beginning_of_month
    first_sunday = first_of_month
    first_sunday += 1.day until first_sunday.sunday?

    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "MONTHLY", "interval" => 1, "byday" => [ "SU" ], "bysetpos" => [ 1 ] }
    @activity.recurrence_start_date = first_of_month

    assert @activity.matches_recurrence_pattern?(first_sunday)

    # Second Sunday should not match
    second_sunday = first_sunday + 1.week
    assert_not @activity.matches_recurrence_pattern?(second_sunday)
  end

  test "matches_recurrence_pattern? matches yearly pattern" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "YEARLY", "interval" => 1 }
    @activity.recurrence_start_date = Date.new(2025, 6, 15)

    assert @activity.matches_recurrence_pattern?(Date.new(2025, 6, 15))
    assert @activity.matches_recurrence_pattern?(Date.new(2026, 6, 15))
    assert_not @activity.matches_recurrence_pattern?(Date.new(2025, 6, 16))
    assert_not @activity.matches_recurrence_pattern?(Date.new(2026, 7, 15))
  end

  test "matches_recurrence_pattern? respects recurrence_end_date" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.recurrence_end_date = Date.current + 5.days

    assert @activity.matches_recurrence_pattern?(Date.current + 3.days)
    assert_not @activity.matches_recurrence_pattern?(Date.current + 10.days)
  end

  test "next_occurrence returns nil for non-recurring activities" do
    @activity.schedule_type = "flexible"
    assert_nil @activity.next_occurrence
  end

  test "next_occurrence finds next occurrence for daily pattern" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.zone.parse("18:00")
    @activity.occurrence_time_end = Time.zone.parse("19:00")

    # If current time is before 6pm today, next occurrence should be today at 6pm
    # If after 6pm, should be tomorrow at 6pm
    next_occ = @activity.next_occurrence(Date.current)
    assert_not_nil next_occ
    assert next_occ > Time.current
  end

  test "next_occurrence finds next occurrence for weekly pattern" do
    monday = Date.current.beginning_of_week
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO" ] }
    @activity.recurrence_start_date = monday
    @activity.occurrence_time_start = Time.zone.parse("10:00")
    @activity.occurrence_time_end = Time.zone.parse("11:00")

    next_occ = @activity.next_occurrence(monday)
    assert_not_nil next_occ
    assert next_occ.monday?
  end

  test "next_occurrence returns nil if no occurrence within 366 days" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO" ] }
    @activity.recurrence_start_date = Date.current - 400.days
    @activity.recurrence_end_date = Date.current - 380.days
    @activity.occurrence_time_start = Time.zone.parse("10:00")
    @activity.occurrence_time_end = Time.zone.parse("11:00")

    assert_nil @activity.next_occurrence
  end

  test "occurrences_in_range returns empty for non-recurring" do
    @activity.schedule_type = "flexible"
    occurrences = @activity.occurrences_in_range(Date.current, Date.current + 1.week)
    assert_empty occurrences
  end

  test "occurrences_in_range finds all daily occurrences" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    occurrences = @activity.occurrences_in_range(Date.current, Date.current + 6.days)
    assert_equal 7, occurrences.length

    occurrences.each do |occ|
      assert_equal 9, occ[:start_time].hour
      assert_equal 10, occ[:end_time].hour
    end
  end

  test "occurrences_in_range finds weekly occurrences" do
    monday = Date.current.beginning_of_week
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO", "WE" ] }
    @activity.recurrence_start_date = monday
    @activity.occurrence_time_start = Time.zone.parse("14:00")
    @activity.occurrence_time_end = Time.zone.parse("15:00")

    occurrences = @activity.occurrences_in_range(monday, monday + 2.weeks)
    # 2 weeks + partial = should have 4-6 occurrences (2 per week)
    assert occurrences.length >= 4
    assert occurrences.all? { |occ| occ[:start_time].monday? || occ[:start_time].wednesday? }
  end

  test "occurrences_in_range respects recurrence_end_date" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.recurrence_end_date = Date.current + 3.days
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    occurrences = @activity.occurrences_in_range(Date.current, Date.current + 10.days)
    assert_equal 4, occurrences.length # Days 0, 1, 2, 3
  end
end
