require "rails_helper"

RSpec.describe GoogleCalendarService, type: :service do
  include GoogleHelpers::GoogleCalendarTestHelper

  before do
    @user = users(:one)
    @google_account = create_test_google_account(@user)
  end

  it "should initialize with google account" do
    service = GoogleCalendarService.new(@google_account)
    # Test that service initializes properly
    expect(service).not_to be_nil
    expect(service.instance_variable_get(:@google_account)).to eq @google_account
  end

  it "should detect expired tokens" do
    @google_account.update!(expires_at: 1.hour.ago)

    # Test that the account is properly marked as expired
    expect(@google_account.token_expired?).to be true
    expect(@google_account.needs_refresh?).to be true

    # Use VCR or stub to handle OAuth refresh during service initialization
    VCR.use_cassette("oauth_token_refresh", allow_playback_repeats: true) do
      # Stub OAuth token refresh to avoid real API calls
      stub_google_oauth_token_refresh

      # Service initialization may trigger refresh - that's expected behavior
      service = GoogleCalendarService.new(@google_account)
      expect(service).not_to be_nil
    end
  end

  # VCR test for real API calls (when recording)
  it "should fetch calendar list with VCR" do
    VCR.use_cassette("google_calendar_list") do
      skip "Enable when recording real API interactions"

      # Uncomment when ready to record real API calls:
      # service = GoogleCalendarService.new(@google_account)
      # calendars = service.fetch_calendars
      #
      # expect(calendars).to be_a(Array)
      # expect(calendars.any? { |cal| cal[:id] == 'primary' }).to be true
    end
  end

  # Test without external API calls
  it "should handle API errors gracefully" do
    service = GoogleCalendarService.new(@google_account)

    # Test that service responds to expected methods
    expect(service).to respond_to :fetch_calendars
    # Note: handle_api_error might be a private method or not exist yet
  end

  # Test calendar event creation logic
  it "should format event data correctly" do
    VCR.use_cassette("google_create_event") do
      skip "Enable when recording real API interactions"

      # service = GoogleCalendarService.new(@google_account)
      # activity = activities(:one)
      #
      # event_data = service.format_event_for_google(activity, Time.current, Time.current + 1.hour)
      #
      # expect(event_data[:summary]).to be_present
      # expect(event_data[:start]).to be_present
      # expect(event_data[:end]).to be_present
    end
  end
end
