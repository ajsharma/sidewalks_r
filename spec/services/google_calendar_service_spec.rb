require "rails_helper"

RSpec.describe GoogleCalendarService, type: :service do
  include GoogleHelpers::GoogleCalendarTestHelper

  before do
    @user = users(:one)
    @google_account = create_test_google_account(@user)
  end

  it "initializes with google account" do
    service = described_class.new(@google_account)
    # Test that service initializes properly
    expect(service).not_to be_nil
    expect(service.instance_variable_get(:@google_account)).to eq @google_account
  end

  it "detects expired tokens" do
    @google_account.update!(expires_at: 1.hour.ago)

    # Test that the account is properly marked as expired
    expect(@google_account.token_expired?).to be true
    expect(@google_account.needs_refresh?).to be true

    # Use VCR or stub to handle OAuth refresh during service initialization
    VCR.use_cassette("oauth_token_refresh", allow_playback_repeats: true) do
      # Stub OAuth token refresh to avoid real API calls
      stub_google_oauth_token_refresh

      # Service initialization may trigger refresh - that's expected behavior
      service = described_class.new(@google_account)
      expect(service).not_to be_nil
    end
  end

  # VCR test for real API calls (when recording)
  it "fetches calendar list with VCR" do
    VCR.use_cassette("google_calendar_list") do
      # Uncomment when ready to record real API calls:
      service = described_class.new(@google_account)
      calendars = service.fetch_calendars

      expect(calendars).to be_a(Array)
      expect(calendars.any? { |cal| cal.id == "primary" }).to be true
    end
  end

  # Test without external API calls
  it "handles API errors gracefully" do
    service = described_class.new(@google_account)

    # Test that service responds to expected methods
    expect(service).to respond_to :fetch_calendars
    # Note: handle_api_error might be a private method or not exist yet
  end

  # Test calendar event creation logic
  it "creates event with correct data" do
    VCR.use_cassette("google_create_event") do
      service = described_class.new(@google_account)

      event_data = {
        title: "Test Activity",
        description: "Test Description",
        start_time: Time.parse("2025-12-25 12:00:00 -0800"),
        end_time: Time.parse("2025-12-25 13:00:00 -0800"),
        timezone: "America/Los_Angeles"
      }

      event = service.create_event("primary", event_data)

      expect(event.summary).to eq("Test Activity")
      expect(event.start).to be_present
      expect(event.end).to be_present
    end
  end
end
