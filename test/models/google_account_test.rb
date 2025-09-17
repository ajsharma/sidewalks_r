require "test_helper"

class GoogleAccountTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @google_account = GoogleAccount.new(
      user: @user,
      email: "test@gmail.com",
      google_id: "123456789",
      access_token: "test_access_token",
      refresh_token: "test_refresh_token",
      expires_at: Time.current + 1.hour
    )
  end

  test "should be valid" do
    assert @google_account.valid?
  end

  test "should require user" do
    @google_account.user = nil
    assert_not @google_account.valid?
    assert_includes @google_account.errors[:user], "must exist"
  end

  test "should require email" do
    @google_account.email = ""
    assert_not @google_account.valid?
    assert_includes @google_account.errors[:email], "can't be blank"
  end

  test "should validate email format" do
    @google_account.email = "invalid_email"
    assert_not @google_account.valid?
    assert_includes @google_account.errors[:email], "is invalid"
  end

  test "should require google_id" do
    @google_account.google_id = ""
    assert_not @google_account.valid?
    assert_includes @google_account.errors[:google_id], "can't be blank"
  end

  test "should require unique google_id per user" do
    @google_account.save!
    duplicate = GoogleAccount.new(
      user: @user,
      email: "different@gmail.com",
      google_id: @google_account.google_id
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:google_id], "has already been taken"
  end

  test "should allow same google_id for different users" do
    @google_account.save!
    other_user = User.create!(
      email: "other@example.com",
      password: "password",
      name: "Other User"
    )
    different_account = GoogleAccount.new(
      user: other_user,
      email: "different@gmail.com",
      google_id: @google_account.google_id
    )
    assert different_account.valid?
  end

  test "archived? should return false when not archived" do
    assert_not @google_account.archived?
  end

  test "archived? should return true when archived" do
    @google_account.archived_at = Time.current
    assert @google_account.archived?
  end

  test "archive! should set archived_at" do
    @google_account.save!
    assert_nil @google_account.archived_at
    @google_account.archive!
    assert_not_nil @google_account.archived_at
  end

  test "token_expired? should return false when token not expired" do
    @google_account.expires_at = Time.current + 1.hour
    assert_not @google_account.token_expired?
  end

  test "token_expired? should return true when token expired" do
    @google_account.expires_at = Time.current - 1.hour
    assert @google_account.token_expired?
  end

  test "token_expired? should return false when expires_at is nil" do
    @google_account.expires_at = nil
    assert_not @google_account.token_expired?
  end

  test "calendars should parse JSON calendar_list" do
    calendar_data = [ { "id" => "primary", "summary" => "Primary Calendar" } ]
    @google_account.calendar_list = calendar_data.to_json
    assert_equal calendar_data, @google_account.calendars
  end

  test "calendars should return empty array for invalid JSON" do
    @google_account.calendar_list = "invalid json"
    assert_equal [], @google_account.calendars
  end

  test "calendars should return empty array when calendar_list is nil" do
    @google_account.calendar_list = nil
    assert_equal [], @google_account.calendars
  end

  test "calendars= should store calendars as JSON" do
    calendar_data = [ { "id" => "primary", "summary" => "Primary Calendar" } ]
    @google_account.calendars = calendar_data
    assert_equal calendar_data.to_json, @google_account.calendar_list
  end

  test "needs_refresh? should return true when token expired" do
    @google_account.expires_at = Time.current - 1.hour
    assert @google_account.needs_refresh?
  end

  test "needs_refresh? should return true when access_token is blank" do
    @google_account.access_token = ""
    assert @google_account.needs_refresh?
  end

  test "needs_refresh? should return false when token valid and present" do
    @google_account.expires_at = Time.current + 1.hour
    @google_account.access_token = "valid_token"
    assert_not @google_account.needs_refresh?
  end

  test "active scope should exclude archived accounts" do
    active_account = google_accounts(:one)
    archived_account = GoogleAccount.create!(
      user: @user,
      email: "archived@gmail.com",
      google_id: "archived123",
      archived_at: Time.current
    )

    active_accounts = GoogleAccount.active
    assert_includes active_accounts, active_account
    assert_not_includes active_accounts, archived_account
  end
end
