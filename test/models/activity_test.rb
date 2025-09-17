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
end
