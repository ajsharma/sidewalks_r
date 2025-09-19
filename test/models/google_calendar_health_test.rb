require "test_helper"

class GoogleCalendarHealthTest < ActiveSupport::TestCase
  test "check_api_connectivity returns healthy when no Google accounts" do
    GoogleAccount.delete_all
    result = GoogleCalendarHealth.check_api_connectivity

    assert_equal "healthy", result[:status]
    assert_equal "No Google accounts configured", result[:message]
  end

  test "check_api_connectivity returns warning when no active accounts" do
    # Create account without access token
    GoogleAccount.create!(
      user: users(:one),
      email: "test@example.com",
      google_id: "123456789",
      refresh_token: "refresh_token"
    )

    result = GoogleCalendarHealth.check_api_connectivity

    assert_equal "warning", result[:status]
    assert_equal "No active Google accounts found", result[:message]
  end

  test "check_api_connectivity returns warning when tokens need refresh" do
    # Create account with expired token
    account = GoogleAccount.create!(
      user: users(:one),
      email: "test@example.com",
      google_id: "123456789",
      access_token: "access_token",
      refresh_token: "refresh_token",
      expires_at: 1.hour.ago
    )

    result = GoogleCalendarHealth.check_api_connectivity

    assert_equal "warning", result[:status]
    assert_equal "Google Calendar tokens need refresh", result[:message]
    assert_includes result.keys, :response_time_ms
  end

  test "check_api_connectivity returns healthy when account is valid" do
    account = GoogleAccount.create!(
      user: users(:one),
      email: "test@example.com",
      google_id: "123456789",
      access_token: "access_token",
      refresh_token: "refresh_token",
      expires_at: 1.hour.from_now
    )

    result = GoogleCalendarHealth.check_api_connectivity

    assert_equal "healthy", result[:status]
    assert_equal "Google Calendar API accessible", result[:message]
    assert_equal 1, result[:active_accounts]
    assert_includes result.keys, :response_time_ms
    assert_instance_of Float, result[:response_time_ms]
  end

  test "check_api_connectivity returns correct structure" do
    account = GoogleAccount.create!(
      user: users(:one),
      email: "test@example.com",
      google_id: "123456789",
      access_token: "access_token",
      refresh_token: "refresh_token",
      expires_at: 1.hour.from_now
    )

    result = GoogleCalendarHealth.check_api_connectivity

    assert_instance_of Hash, result
    assert_includes result.keys, :status
    assert_includes result.keys, :message
    assert_includes result.keys, :response_time_ms
  end

  test "find_recent_active_account returns most recently updated account" do
    # Create multiple accounts
    old_account = GoogleAccount.create!(
      user: users(:one),
      email: "old@example.com",
      google_id: "123456789",
      access_token: "old_token",
      refresh_token: "old_refresh",
      expires_at: 1.hour.from_now
    )

    new_account = GoogleAccount.create!(
      user: users(:one),
      email: "new@example.com",
      google_id: "987654321",
      access_token: "new_token",
      refresh_token: "new_refresh",
      expires_at: 1.hour.from_now
    )

    # Update the new account to make it more recent
    new_account.touch

    result = GoogleCalendarHealth.send(:find_recent_active_account)
    assert_equal new_account, result
  end

  test "find_recent_active_account ignores accounts without access token" do
    GoogleAccount.create!(
      user: users(:one),
      email: "no_token@example.com",
      google_id: "123456789",
      refresh_token: "refresh_token"
    )

    result = GoogleCalendarHealth.send(:find_recent_active_account)
    assert_nil result
  end

  test "response_time_ms calculates correct duration" do
    start_time = Time.current - 0.05 # 50ms ago
    response_time = GoogleCalendarHealth.send(:response_time_ms, start_time)

    assert_instance_of Float, response_time
    assert response_time > 0
    assert response_time < 1000 # Should be less than 1 second in test environment
  end
end
