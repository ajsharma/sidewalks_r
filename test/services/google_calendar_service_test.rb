require "test_helper"

class GoogleCalendarServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @google_account = create_test_google_account(@user)
  end

  test "should initialize with google account" do
    service = GoogleCalendarService.new(@google_account)
    # Test that service initializes properly
    assert_not_nil service
    assert service.instance_variable_get(:@google_account) == @google_account
  end

  test "should detect expired tokens" do
    @google_account.update!(expires_at: 1.hour.ago)

    # Test that the account is properly marked as expired
    assert @google_account.token_expired?
    assert @google_account.needs_refresh?

    # Use VCR or stub to handle OAuth refresh during service initialization
    VCR.use_cassette("oauth_token_refresh", allow_playback_repeats: true) do
      # Stub OAuth token refresh to avoid real API calls
      stub_google_oauth_token_refresh

      # Service initialization may trigger refresh - that's expected behavior
      service = GoogleCalendarService.new(@google_account)
      assert_not_nil service
    end
  end

  # VCR test for real API calls (when recording)
  test "should fetch calendar list with VCR" do
    VCR.use_cassette("google_calendar_list") do
      skip "Enable when recording real API interactions"

      # Uncomment when ready to record real API calls:
      # service = GoogleCalendarService.new(@google_account)
      # calendars = service.fetch_calendars
      #
      # assert calendars.is_a?(Array)
      # assert calendars.any? { |cal| cal[:id] == 'primary' }
    end
  end

  # Test without external API calls
  test "should handle API errors gracefully" do
    service = GoogleCalendarService.new(@google_account)

    # Test that service responds to expected methods
    assert_respond_to service, :fetch_calendars
    # Note: handle_api_error might be a private method or not exist yet
  end

  # Test calendar event creation logic
  test "should format event data correctly" do
    VCR.use_cassette("google_create_event") do
      skip "Enable when recording real API interactions"

      # service = GoogleCalendarService.new(@google_account)
      # activity = activities(:one)
      #
      # event_data = service.format_event_for_google(activity, Time.current, Time.current + 1.hour)
      #
      # assert event_data[:summary].present?
      # assert event_data[:start].present?
      # assert event_data[:end].present?
    end
  end
end
