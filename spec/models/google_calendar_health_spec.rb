require "rails_helper"

RSpec.describe GoogleCalendarHealth, type: :model do
  it "check_api_connectivity returns healthy when no Google accounts" do
    GoogleAccount.delete_all
    result = described_class.check_api_connectivity

    expect(result[:status]).to eq("healthy")
    expect(result[:message]).to eq("No Google accounts configured")
  end

  it "check_api_connectivity returns warning when no active accounts" do
    # Create account without access token
    GoogleAccount.create!(
      user: users(:one),
      email: "test@example.com",
      google_id: "123456789",
      refresh_token: "refresh_token"
    )

    result = described_class.check_api_connectivity

    expect(result[:status]).to eq("warning")
    expect(result[:message]).to eq("No active Google accounts found")
  end

  it "check_api_connectivity returns warning when tokens need refresh" do
    # Create account with expired token
    account = GoogleAccount.create!(
      user: users(:one),
      email: "test@example.com",
      google_id: "123456789",
      access_token: "access_token",
      refresh_token: "refresh_token",
      expires_at: 1.hour.ago
    )

    result = described_class.check_api_connectivity

    expect(result[:status]).to eq("warning")
    expect(result[:message]).to eq("Google Calendar tokens need refresh")
    expect(result.keys).to include(:response_time_ms)
  end

  it "check_api_connectivity returns healthy when account is valid" do
    account = GoogleAccount.create!(
      user: users(:one),
      email: "test@example.com",
      google_id: "123456789",
      access_token: "access_token",
      refresh_token: "refresh_token",
      expires_at: 1.hour.from_now
    )

    result = described_class.check_api_connectivity

    expect(result[:status]).to eq("healthy")
    expect(result[:message]).to eq("Google Calendar API accessible")
    expect(result[:active_accounts]).to eq(1)
    expect(result.keys).to include(:response_time_ms)
    expect(result[:response_time_ms]).to be_an_instance_of(Float)
  end

  it "check_api_connectivity returns correct structure" do
    account = GoogleAccount.create!(
      user: users(:one),
      email: "test@example.com",
      google_id: "123456789",
      access_token: "access_token",
      refresh_token: "refresh_token",
      expires_at: 1.hour.from_now
    )

    result = described_class.check_api_connectivity

    expect(result).to be_an_instance_of(Hash)
    expect(result.keys).to include(:status)
    expect(result.keys).to include(:message)
    expect(result.keys).to include(:response_time_ms)
  end

  it "find_recent_active_account returns most recently updated account" do
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

    result = described_class.send(:find_recent_active_account)
    expect(result).to eq(new_account)
  end

  it "find_recent_active_account ignores accounts without access token" do
    GoogleAccount.create!(
      user: users(:one),
      email: "no_token@example.com",
      google_id: "123456789",
      refresh_token: "refresh_token"
    )

    result = described_class.send(:find_recent_active_account)
    expect(result).to be_nil
  end

  it "response_time_ms calculates correct duration" do
    start_time = Time.current - 0.05 # 50ms ago
    response_time = described_class.send(:response_time_ms, start_time)

    expect(response_time).to be_an_instance_of(Float)
    expect(response_time).to be > 0
    expect(response_time).to be < 1000 # Should be less than 1 second in test environment
  end
end
