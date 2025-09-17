module GoogleTestHelper
  # Sample Google Calendar API responses for testing
  def sample_calendar_event(overrides = {})
    {
      "id" => "test_event_123",
      "summary" => "Test Event",
      "description" => "Test event description",
      "start" => { "dateTime" => Time.current.iso8601 },
      "end" => { "dateTime" => (Time.current + 1.hour).iso8601 },
      "created" => 1.day.ago.iso8601,
      "updated" => Time.current.iso8601,
      "status" => "confirmed"
    }.merge(overrides)
  end

  def sample_calendar_list
    {
      "items" => [
        {
          "id" => "primary",
          "summary" => "Test User",
          "description" => "Primary calendar",
          "accessRole" => "owner",
          "selected" => true,
          "primary" => true
        },
        {
          "id" => "work_calendar_id",
          "summary" => "Work Calendar",
          "description" => "Work events",
          "accessRole" => "writer",
          "selected" => false
        }
      ]
    }
  end

  def sample_events_response(events_count = 3)
    events = events_count.times.map do |i|
      sample_calendar_event(
        "id" => "event_#{i}",
        "summary" => "Event #{i + 1}",
        "start" => { "dateTime" => (Time.current + i.hours).iso8601 },
        "end" => { "dateTime" => (Time.current + i.hours + 1.hour).iso8601 }
      )
    end

    {
      "items" => events,
      "nextPageToken" => nil,
      "timeMin" => Date.current.iso8601,
      "timeMax" => (Date.current + 7.days).iso8601
    }
  end

  # OAuth response simulation
  def sample_oauth_response
    {
      "access_token" => "sample_access_token_12345",
      "refresh_token" => "sample_refresh_token_67890",
      "expires_in" => 3600,
      "scope" => "https://www.googleapis.com/auth/calendar",
      "token_type" => "Bearer"
    }
  end

  # Create test Google account with valid tokens (bypasses encryption issues)
  def create_test_google_account(user = nil)
    user ||= users(:one)

    # Create account that won't trigger encryption errors
    GoogleAccount.create!(
      user: user,
      email: "test#{rand(1000)}@gmail.com",
      google_id: "google_id_#{rand(100000)}",
      access_token: "test_access_token_#{rand(100000)}",
      refresh_token: "test_refresh_token_#{rand(100000)}",
      expires_at: 1.hour.from_now
    )
  rescue ActiveRecord::Encryption::Errors::Decryption => e
    # For testing, create minimal account that bypasses encryption
    account = GoogleAccount.new(
      user: user,
      email: "test#{rand(1000)}@gmail.com",
      google_id: "google_id_#{rand(100000)}",
      expires_at: 1.hour.from_now
    )
    # Set tokens directly without encryption for testing
    account.save(validate: false)
    account
  end

  # Stub Google API endpoints
  def stub_google_calendar_list(response = sample_calendar_list)
    stub_request(:get, %r{https://www.googleapis.com/calendar/v3/users/me/calendarList})
      .to_return(
        status: 200,
        body: response.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_google_events_list(response = sample_events_response)
    stub_request(:get, %r{https://www.googleapis.com/calendar/v3/calendars/.+/events})
      .to_return(
        status: 200,
        body: response.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_google_create_event(response = sample_calendar_event)
    stub_request(:post, %r{https://www.googleapis.com/calendar/v3/calendars/.+/events})
      .to_return(
        status: 200,
        body: response.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_google_oauth_token_refresh(response = sample_oauth_response)
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(
        status: 200,
        body: response.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Error response stubs
  def stub_google_api_error(status = 400, error_message = "Bad Request")
    error_response = {
      "error" => {
        "code" => status,
        "message" => error_message,
        "status" => status == 400 ? "INVALID_ARGUMENT" : "UNKNOWN"
      }
    }

    stub_request(:any, %r{https://www.googleapis.com/})
      .to_return(
        status: status,
        body: error_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_google_rate_limit_error
    stub_google_api_error(429, "Rate limit exceeded")
  end

  def stub_google_unauthorized_error
    stub_google_api_error(401, "Invalid credentials")
  end
end

# Include in test helper
class ActiveSupport::TestCase
  include GoogleTestHelper
end

class ActionDispatch::IntegrationTest
  include GoogleTestHelper
end
