require "rails_helper"

RSpec.describe Activity, type: :model do
  before do
    @user = users(:one)
    @activity = described_class.new(
      user: @user,
      name: "Test Activity",
      description: "Test description",
      schedule_type: "flexible"
    )
  end

  it "is valid" do
    expect(@activity).to be_valid
  end

  it "requires user" do
    @activity.user = nil
    expect(@activity).not_to be_valid
    expect(@activity.errors[:user]).to include("must exist")
  end

  it "requires name" do
    @activity.name = ""
    expect(@activity).not_to be_valid
    expect(@activity.errors[:name]).to include("can't be blank")
  end

  it "requires valid schedule_type" do
    @activity.schedule_type = "invalid"
    expect(@activity).not_to be_valid
    expect(@activity.errors[:schedule_type]).to include("is not included in the list")
  end

  it "allows valid schedule_types" do
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

      expect(@activity).to be_valid, "#{type} should be valid. Errors: #{@activity.errors.full_messages}"
    end
  end

  it "validates max_frequency_days inclusion" do
    @activity.max_frequency_days = 999
    expect(@activity).not_to be_valid
    expect(@activity.errors[:max_frequency_days]).to include("is not included in the list")
  end

  it "allows valid max_frequency_days" do
    Activity::MAX_FREQUENCY_OPTIONS.each do |option|
      @activity.max_frequency_days = option
      expect(@activity).to be_valid, "#{option} should be valid"
    end
  end

  it "generates slug from name" do
    @activity.save!
    expect(@activity.slug).to eq("test-activity")
  end

  it "generates unique slug when name conflicts" do
    @activity.save!
    activity2 = described_class.create!(
      user: @user,
      name: "Test Activity",
      schedule_type: "flexible"
    )
    expect(activity2.slug).to eq("test-activity-1")
  end

  it "uses to_param as slug" do
    @activity.save!
    expect(@activity.to_param).to eq(@activity.slug)
  end

  it "archived? should return false when not archived" do
    expect(@activity).not_to be_archived
  end

  it "archived? should return true when archived" do
    @activity.archived_at = Time.current
    expect(@activity).to be_archived
  end

  it "archive! should set archived_at" do
    @activity.save!
    expect(@activity.archived_at).to be_nil
    @activity.archive!
    expect(@activity.archived_at).not_to be_nil
  end

  it "strict_schedule? should return true for strict activities" do
    @activity.schedule_type = "strict"
    expect(@activity).to be_strict_schedule
  end

  it "flexible_schedule? should return true for flexible activities" do
    @activity.schedule_type = "flexible"
    expect(@activity).to be_flexible_schedule
  end

  it "deadline_based? should return true for deadline activities" do
    @activity.schedule_type = "deadline"
    expect(@activity).to be_deadline_based
  end

  it "has_deadline? should return true when deadline is set" do
    @activity.deadline = Time.current + 1.day
    expect(@activity).to have_deadline
  end

  it "has_deadline? should return false when deadline is nil" do
    @activity.deadline = nil
    expect(@activity).not_to have_deadline
  end

  it "expired? should return true when deadline has passed" do
    @activity.deadline = Time.current - 1.day
    expect(@activity).to be_expired
  end

  it "expired? should return false when deadline is in future" do
    @activity.deadline = Time.current + 1.day
    expect(@activity).not_to be_expired
  end

  it "expired? should return false when no deadline" do
    @activity.deadline = nil
    expect(@activity).not_to be_expired
  end

  it "activity_links should parse JSON links" do
    @activity.links = '[{"url": "https://example.com", "title": "Example"}]'
    expected = [ { "url" => "https://example.com", "title" => "Example" } ]
    expect(@activity.activity_links).to eq(expected)
  end

  it "activity_links should return empty array for invalid JSON" do
    @activity.links = "invalid json"
    expect(@activity.activity_links).to eq([])
  end

  it "activity_links should return empty array when links is nil" do
    @activity.links = nil
    expect(@activity.activity_links).to eq([])
  end

  it "activity_links= should store links as JSON" do
    links = [ { "url" => "https://example.com", "title" => "Example" } ]
    @activity.activity_links = links
    expect(@activity.links).to eq(links.to_json)
  end

  it "max_frequency_description should return correct descriptions" do
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
      expect(@activity.max_frequency_description).to eq(expected)
    end
  end

  # AI-related tests
  it "has_many ai_suggestions association" do
    activity = activities(:one)
    suggestion = ai_activity_suggestions(:text_completed)
    suggestion.update!(final_activity: activity, accepted: true)

    expect(activity.ai_suggestions).to include(suggestion)
  end

  # Phase 1: Recurring events and duration fields
  it "allows recurring_strict schedule type" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO" ] }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.parse("18:00")
    @activity.occurrence_time_end = Time.parse("19:00")

    expect(@activity).to be_valid, "recurring_strict should be valid. Errors: #{@activity.errors.full_messages}"
  end

  it "stores recurrence_rule as jsonb" do
    recurrence_rule = { "freq" => "MONTHLY", "interval" => 1, "byday" => [ "SU" ], "bysetpos" => [ 1 ] }
    @activity.recurrence_rule = recurrence_rule
    @activity.save!

    @activity.reload
    expect(@activity.recurrence_rule).to eq(recurrence_rule)
  end

  it "stores recurrence dates" do
    start_date = Date.current
    end_date = 3.months.from_now.to_date

    @activity.recurrence_start_date = start_date
    @activity.recurrence_end_date = end_date
    @activity.save!

    @activity.reload
    expect(@activity.recurrence_start_date).to eq(start_date)
    expect(@activity.recurrence_end_date).to eq(end_date)
  end

  it "stores occurrence times" do
    # Use Time.zone.parse to get times in the application's timezone
    start_time = Time.zone.parse("09:00")
    end_time = Time.zone.parse("12:00")

    @activity.occurrence_time_start = start_time
    @activity.occurrence_time_end = end_time
    @activity.save!

    @activity.reload
    # Compare just the time component (hour, minute, second)
    expect(@activity.occurrence_time_start.strftime("%H:%M:%S")).to eq("09:00:00")
    expect(@activity.occurrence_time_end.strftime("%H:%M:%S")).to eq("12:00:00")
  end

  it "stores duration_minutes" do
    @activity.duration_minutes = 120
    @activity.save!

    @activity.reload
    expect(@activity.duration_minutes).to eq(120)
  end

  it "allows nil duration_minutes" do
    @activity.duration_minutes = nil
    expect(@activity).to be_valid
  end

  # Phase 2: Validation tests

  it "recurring_strict requires recurrence_rule" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    expect(@activity).not_to be_valid
    expect(@activity.errors[:recurrence_rule]).to include("is required for recurring events")
  end

  it "recurring_strict requires recurrence_start_date" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1 }
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    expect(@activity).not_to be_valid
    expect(@activity.errors[:recurrence_start_date]).to include("is required for recurring events")
  end

  it "recurring_strict requires occurrence_time_start" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    expect(@activity).not_to be_valid
    expect(@activity.errors[:occurrence_time_start]).to include("is required for recurring events")
  end

  it "recurring_strict requires occurrence_time_end" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.zone.parse("09:00")

    expect(@activity).not_to be_valid
    expect(@activity.errors[:occurrence_time_end]).to include("is required for recurring events")
  end

  it "occurrence_time_end must be after occurrence_time_start" do
    @activity.occurrence_time_start = Time.zone.parse("10:00")
    @activity.occurrence_time_end = Time.zone.parse("09:00")

    expect(@activity).not_to be_valid
    expect(@activity.errors[:occurrence_time_end]).to include("must be after start time")
  end

  it "occurrence_time_end cannot equal occurrence_time_start" do
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("09:00")

    expect(@activity).not_to be_valid
    expect(@activity.errors[:occurrence_time_end]).to include("must be after start time")
  end

  it "recurrence_rule must have valid frequency" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "INVALID" }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("10:00")

    expect(@activity).not_to be_valid
    expect(@activity.errors[:recurrence_rule]).to include("must have valid freq: DAILY, WEEKLY, MONTHLY, YEARLY")
  end

  it "duration_minutes must be greater than 0" do
    @activity.duration_minutes = 0

    expect(@activity).not_to be_valid
    expect(@activity.errors[:duration_minutes]).to include("must be greater than 0")
  end

  it "duration_minutes must be greater than 0 when negative" do
    @activity.duration_minutes = -10

    expect(@activity).not_to be_valid
    expect(@activity.errors[:duration_minutes]).to include("must be greater than 0")
  end

  it "duration_minutes cannot exceed 720 minutes" do
    @activity.duration_minutes = 721

    expect(@activity).not_to be_valid
    expect(@activity.errors[:duration_minutes]).to include("cannot exceed 720 minutes (12 hours)")
  end

  it "duration_minutes allows 720 minutes" do
    @activity.duration_minutes = 720
    expect(@activity).to be_valid
  end

  # Phase 2: Duration helper tests

  it "occurrence_duration_minutes calculates from occurrence times" do
    @activity.occurrence_time_start = Time.zone.parse("14:00")
    @activity.occurrence_time_end = Time.zone.parse("16:30")

    expect(@activity.occurrence_duration_minutes).to eq(150)
  end

  it "occurrence_duration_minutes returns nil when times not set" do
    expect(@activity.occurrence_duration_minutes).to be_nil
  end

  it "calculated_duration_minutes calculates from start and end times" do
    @activity.start_time = Time.current
    @activity.end_time = Time.current + 3.hours

    expect(@activity.calculated_duration_minutes).to eq(180)
  end

  it "calculated_duration_minutes returns nil when times not set" do
    expect(@activity.calculated_duration_minutes).to be_nil
  end

  it "time_windowed? returns true for strict activity with shorter duration" do
    @activity.schedule_type = "strict"
    @activity.start_time = Time.current
    @activity.end_time = Time.current + 3.hours
    @activity.duration_minutes = 120

    expect(@activity).to be_time_windowed
  end

  it "time_windowed? returns false for strict activity with matching duration" do
    @activity.schedule_type = "strict"
    @activity.start_time = Time.current
    @activity.end_time = Time.current + 2.hours
    @activity.duration_minutes = 120

    expect(@activity).not_to be_time_windowed
  end

  it "time_windowed? returns true for recurring_strict with shorter duration" do
    @activity.schedule_type = "recurring_strict"
    @activity.occurrence_time_start = Time.zone.parse("09:00")
    @activity.occurrence_time_end = Time.zone.parse("12:00")
    @activity.duration_minutes = 120

    expect(@activity).to be_time_windowed
  end

  it "time_windowed? returns false for flexible activity" do
    @activity.schedule_type = "flexible"
    @activity.duration_minutes = 60

    expect(@activity).not_to be_time_windowed
  end

  it "time_window returns details for strict time-windowed activity" do
    start = Time.current.change(usec: 0)
    finish = start + 3.hours
    @activity.schedule_type = "strict"
    @activity.start_time = start
    @activity.end_time = finish
    @activity.duration_minutes = 120

    window = @activity.time_window
    expect(window[:start]).to eq(start)
    expect(window[:end]).to eq(finish)
    expect(window[:duration]).to eq(180)
    expect(window[:attendance_duration]).to eq(120)
  end

  it "time_window returns details for recurring_strict time-windowed activity" do
    start_time = Time.zone.parse("09:00")
    end_time = Time.zone.parse("12:00")
    @activity.schedule_type = "recurring_strict"
    @activity.occurrence_time_start = start_time
    @activity.occurrence_time_end = end_time
    @activity.duration_minutes = 120

    window = @activity.time_window
    # Compare just the hour and minute since occurrence times don't have date context
    expect(window[:start].hour).to eq(start_time.hour)
    expect(window[:start].min).to eq(start_time.min)
    expect(window[:end].hour).to eq(end_time.hour)
    expect(window[:end].min).to eq(end_time.min)
    expect(window[:duration]).to eq(180)
    expect(window[:attendance_duration]).to eq(120)
  end

  it "time_window returns nil for non-windowed activity" do
    @activity.schedule_type = "flexible"
    expect(@activity.time_window).to be_nil
  end

  # Phase 2: Recurrence helper tests

  it "recurring_strict? returns true for recurring_strict activities" do
    @activity.schedule_type = "recurring_strict"
    expect(@activity).to be_recurring_strict
  end

  it "recurring_strict? returns false for other schedule types" do
    @activity.schedule_type = "flexible"
    expect(@activity).not_to be_recurring_strict
  end

  it "matches_recurrence_pattern? returns false for non-recurring activities" do
    @activity.schedule_type = "flexible"
    expect(@activity).not_to be_matches_recurrence_pattern(Date.current)
  end

  it "matches_recurrence_pattern? matches daily pattern" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current

    expect(@activity).to be_matches_recurrence_pattern(Date.current)
    expect(@activity).to be_matches_recurrence_pattern(Date.current + 1.day)
    expect(@activity).to be_matches_recurrence_pattern(Date.current + 2.days)
  end

  it "matches_recurrence_pattern? matches daily pattern with interval" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 2 }
    @activity.recurrence_start_date = Date.current

    expect(@activity).to be_matches_recurrence_pattern(Date.current)
    expect(@activity).not_to be_matches_recurrence_pattern(Date.current + 1.day)
    expect(@activity).to be_matches_recurrence_pattern(Date.current + 2.days)
  end

  it "matches_recurrence_pattern? matches weekly pattern" do
    # Start on a Monday
    monday = Date.current.beginning_of_week
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO" ] }
    @activity.recurrence_start_date = monday

    expect(@activity).to be_matches_recurrence_pattern(monday)
    expect(@activity).to be_matches_recurrence_pattern(monday + 1.week)
    expect(@activity).not_to be_matches_recurrence_pattern(monday + 1.day)
  end

  it "matches_recurrence_pattern? matches weekly pattern with multiple days" do
    monday = Date.current.beginning_of_week
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO", "WE", "FR" ] }
    @activity.recurrence_start_date = monday

    expect(@activity).to be_matches_recurrence_pattern(monday) # Monday
    expect(@activity).not_to be_matches_recurrence_pattern(monday + 1.day) # Tuesday
    expect(@activity).to be_matches_recurrence_pattern(monday + 2.days) # Wednesday
    expect(@activity).not_to be_matches_recurrence_pattern(monday + 3.days) # Thursday
    expect(@activity).to be_matches_recurrence_pattern(monday + 4.days) # Friday
  end

  it "matches_recurrence_pattern? matches monthly pattern by monthday" do
    first_of_month = Date.current.beginning_of_month
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "MONTHLY", "interval" => 1, "bymonthday" => [ 15 ] }
    @activity.recurrence_start_date = first_of_month

    expect(@activity).to be_matches_recurrence_pattern(first_of_month + 14.days) # 15th
    expect(@activity).not_to be_matches_recurrence_pattern(first_of_month + 13.days) # 14th
    expect(@activity).not_to be_matches_recurrence_pattern(first_of_month + 15.days) # 16th
  end

  it "matches_recurrence_pattern? matches monthly pattern by position - first Sunday" do
    # Find first Sunday of current month
    first_of_month = Date.current.beginning_of_month
    first_sunday = first_of_month
    first_sunday += 1.day until first_sunday.sunday?

    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "MONTHLY", "interval" => 1, "byday" => [ "SU" ], "bysetpos" => [ 1 ] }
    @activity.recurrence_start_date = first_of_month

    expect(@activity).to be_matches_recurrence_pattern(first_sunday)

    # Second Sunday should not match
    second_sunday = first_sunday + 1.week
    expect(@activity).not_to be_matches_recurrence_pattern(second_sunday)
  end

  it "matches_recurrence_pattern? matches yearly pattern" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "YEARLY", "interval" => 1 }
    @activity.recurrence_start_date = Date.new(2025, 6, 15)

    expect(@activity).to be_matches_recurrence_pattern(Date.new(2025, 6, 15))
    expect(@activity).to be_matches_recurrence_pattern(Date.new(2026, 6, 15))
    expect(@activity).not_to be_matches_recurrence_pattern(Date.new(2025, 6, 16))
    expect(@activity).not_to be_matches_recurrence_pattern(Date.new(2026, 7, 15))
  end

  it "matches_recurrence_pattern? respects recurrence_end_date" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.recurrence_end_date = Date.current + 5.days

    expect(@activity).to be_matches_recurrence_pattern(Date.current + 3.days)
    expect(@activity).not_to be_matches_recurrence_pattern(Date.current + 10.days)
  end

  it "next_occurrence returns nil for non-recurring activities" do
    @activity.schedule_type = "flexible"
    expect(@activity.next_occurrence).to be_nil
  end

  it "next_occurrence finds next occurrence for daily pattern" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "DAILY", "interval" => 1 }
    @activity.recurrence_start_date = Date.current
    @activity.occurrence_time_start = Time.zone.parse("18:00")
    @activity.occurrence_time_end = Time.zone.parse("19:00")

    # If current time is before 6pm today, next occurrence should be today at 6pm
    # If after 6pm, should be tomorrow at 6pm
    next_occ = @activity.next_occurrence(Date.current)
    expect(next_occ).not_to be_nil
    expect(next_occ).to be > Time.current
  end

  it "next_occurrence finds next occurrence for weekly pattern" do
    monday = Date.current.beginning_of_week
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO" ] }
    @activity.recurrence_start_date = monday
    @activity.occurrence_time_start = Time.zone.parse("10:00")
    @activity.occurrence_time_end = Time.zone.parse("11:00")

    next_occ = @activity.next_occurrence(monday)
    expect(next_occ).not_to be_nil
    expect(next_occ).to be_monday
  end

  it "next_occurrence returns nil if no occurrence within 366 days" do
    @activity.schedule_type = "recurring_strict"
    @activity.recurrence_rule = { "freq" => "WEEKLY", "interval" => 1, "byday" => [ "MO" ] }
    @activity.recurrence_start_date = Date.current - 400.days
    @activity.recurrence_end_date = Date.current - 380.days
    @activity.occurrence_time_start = Time.zone.parse("10:00")
    @activity.occurrence_time_end = Time.zone.parse("11:00")

    expect(@activity.next_occurrence).to be_nil
  end

end
