# Google Integrations Testing Guide

Complete guide for testing Google API integrations in the Sidewalks application, combining setup instructions with comprehensive testing strategies.

## Testing Strategy Overview

### **3-Tier Testing Approach**

1. **Fast Unit Tests**: Mock/stub Google APIs for rapid development feedback
2. **VCR Integration Tests**: Record real API interactions for realistic testing scenarios
3. **Manual Integration Tests**: End-to-end testing with live Google accounts

### **Benefits of This Approach**
- **Fast Development**: Most tests run without external API calls
- **Reliable CI/CD**: Tests don't depend on external services being available
- **Realistic Testing**: VCR provides actual API response formats and edge cases
- **Error Coverage**: Easy to test error scenarios (rate limits, timeouts) with stubs
- **No API Quotas**: Recorded interactions don't count against Google's usage limits

## Tools and Setup

### **Testing Tools**
- **VCR (Video Cassette Recorder)**: Records real HTTP interactions for reliable playback
- **WebMock**: Stubs HTTP requests for controlled testing scenarios
- **Test Helpers**: Pre-built utilities for common Google API responses

### **Current Test Structure**
```
test/
├── integration/google_integration_test.rb    # OAuth flows and API integration
├── services/google_calendar_service_test.rb  # Service layer unit testing
├── support/google_test_helper.rb             # Test utilities and stubs
└── vcr_cassettes/                            # Recorded API interactions
    ├── google_calendar_events.yml
    ├── oauth_token_refresh.yml
    └── calendar_list.yml
```

## Quick Start Guide

### **Running Existing Tests**

```bash
# Run all tests (uses mocks/VCR cassettes)
bin/rails test

# Run Google-specific tests
bin/rails test test/integration/google_integration_test.rb
bin/rails test test/services/google_calendar_service_test.rb

# Run with verbose output to see skipped tests
bin/rails test --verbose
```

### **Current Test Coverage**
- ✅ **OAuth Flow**: User authentication and token management
- ✅ **API Error Handling**: Rate limits, timeouts, invalid responses
- ✅ **Token Refresh**: Automatic token renewal mechanisms
- ✅ **Calendar Operations**: List calendars, fetch events, create events
- ✅ **Batch Operations**: Multiple event creation with rate limiting
- ✅ **Business Logic**: Activity scheduling and calendar integration

### **Example Test Patterns**

#### Mock-based Testing (Fast - Development)
```ruby
test "should handle calendar list fetching" do
  stub_google_calendar_list  # Uses pre-built mock responses

  service = GoogleCalendarService.new(@google_account)
  calendars = service.fetch_calendars

  assert calendars.any? { |cal| cal[:id] == 'primary' }
  assert_equal 2, calendars.size
end
```

#### VCR-based Testing (Realistic - Integration)
```ruby
test "should fetch real calendar events" do
  VCR.use_cassette("google_calendar_events") do
    service = GoogleCalendarService.new(@google_account)
    events = service.list_events('primary', Date.current, Date.current + 7.days)

    assert events.present?
    assert events.first['summary'].present?
  end
end
```

## Setting Up Real Google Testing

### **1. Test Google Account Setup**

1. **Create separate Google Cloud project** for testing
2. **Enable Calendar API** in the project console
3. **Create OAuth 2.0 credentials**:
   - Application type: Web application
   - Authorized redirect URIs: `http://localhost:3000/users/auth/google_oauth2/callback`
4. **Create dedicated test Google account** with sample calendar data
5. **Generate test calendars** with various event types for comprehensive testing

### **2. Environment Configuration**

Create `.env.test` with testing credentials:

```bash
# Test Google OAuth credentials (use separate test project)
GOOGLE_CLIENT_ID=your_test_project_client_id
GOOGLE_CLIENT_SECRET=your_test_project_client_secret

# Test account tokens (for recording VCR cassettes)
GOOGLE_ACCESS_TOKEN=your_test_account_access_token
GOOGLE_REFRESH_TOKEN=your_test_account_refresh_token
```

### **3. Recording VCR Cassettes**

#### Initial Recording Process:
```bash
# 1. Set up real test credentials in .env.test
# 2. Remove existing cassettes to re-record
rm test/vcr_cassettes/google_calendar_events.yml

# 3. Enable recording in specific test (remove skip statements)
# 4. Run tests to record interactions
bin/rails test test/integration/google_integration_test.rb:test_should_fetch_real_calendar_events_with_VCR

# 5. Commit new cassettes to version control
git add test/vcr_cassettes/ && git commit -m "Update VCR cassettes"
```

#### Example Recording Test:
```ruby
test "should fetch calendar events with VCR" do
  # Skip this test unless explicitly recording
  skip "VCR recording test - enable for recording new cassettes" unless ENV['RECORD_VCR']

  VCR.use_cassette("google_calendar_events", record: :new_episodes) do
    service = GoogleCalendarService.new(@google_account)
    events = service.list_events('primary', Date.current, Date.current + 7.days)

    assert events.present?
    assert events.first.key?('summary')
    assert events.first.key?('start')
  end
end
```

## Comprehensive Test Categories

### **1. Authentication & Authorization Tests**

```ruby
# OAuth flow testing
test "should handle Google OAuth callback" do
  VCR.use_cassette("oauth_callback") do
    # Test complete OAuth token exchange
    # Verify GoogleAccount creation with encrypted tokens
    # Check proper user association and permissions
  end
end

# Token refresh testing
test "should refresh expired tokens automatically" do
  # Create account with expired token
  expired_account = create_test_google_account
  expired_account.update!(expires_at: 1.hour.ago)

  VCR.use_cassette("oauth_token_refresh") do
    service = GoogleCalendarService.new(expired_account)
    calendars = service.fetch_calendars

    # Verify token was refreshed automatically
    expired_account.reload
    assert expired_account.expires_at > Time.current
    assert calendars.present?
  end
end

# Authorization error handling
test "should handle revoked tokens gracefully" do
  stub_google_unauthorized_error

  service = GoogleCalendarService.new(@google_account)

  assert_raises(Google::Apis::AuthorizationError) do
    service.fetch_calendars
  end

  # Verify account tokens are cleared
  @google_account.reload
  assert_nil @google_account.access_token
end
```

### **2. Calendar API Operation Tests**

```ruby
# Calendar listing with various access levels
test "should fetch user calendars with proper access roles" do
  VCR.use_cassette("calendar_list_detailed") do
    service = GoogleCalendarService.new(@google_account)
    calendars = service.fetch_calendars

    primary_calendar = calendars.find { |cal| cal[:primary] }
    work_calendar = calendars.find { |cal| cal[:summary] == 'Work Calendar' }

    assert primary_calendar[:access_role] == 'owner'
    assert work_calendar[:access_role].in?(['writer', 'reader'])
  end
end

# Event creation with various data types
test "should create calendar events with full metadata" do
  VCR.use_cassette("create_detailed_event") do
    activity = activities(:with_deadline)
    event_data = {
      title: activity.name,
      description: activity.description,
      start_time: 1.hour.from_now,
      end_time: 2.hours.from_now,
      timezone: 'America/Los_Angeles'
    }

    service = GoogleCalendarService.new(@google_account)
    result = service.create_event('primary', event_data)

    assert result['id'].present?
    assert_equal activity.name, result['summary']
    assert result['start']['dateTime'].present?
    assert result['end']['dateTime'].present?
  end
end

# Event querying with date ranges
test "should fetch events within specific date ranges" do
  VCR.use_cassette("events_date_range") do
    service = GoogleCalendarService.new(@google_account)
    start_date = Date.current
    end_date = Date.current + 2.weeks

    events = service.list_events('primary', start_date, end_date)

    # Verify all events fall within range
    events.each do |event|
      event_date = Date.parse(event['start']['dateTime'])
      assert event_date.between?(start_date, end_date)
    end
  end
end
```

### **3. Error Handling & Resilience Tests**

```ruby
# API rate limiting scenarios
test "should handle rate limiting gracefully" do
  stub_google_rate_limit_error

  service = GoogleCalendarService.new(@google_account)

  assert_raises(Google::Apis::RateLimitError) do
    service.fetch_calendars
  end
end

# Network timeout handling
test "should handle API timeouts" do
  stub_request(:get, %r{googleapis.com/calendar})
    .to_timeout

  service = GoogleCalendarService.new(@google_account)

  assert_raises(Net::TimeoutError) do
    service.list_events('primary', Date.current, Date.current + 7.days)
  end
end

# Malformed response handling
test "should handle malformed API responses" do
  stub_request(:get, %r{googleapis.com/calendar})
    .to_return(status: 200, body: 'invalid json', headers: {})

  service = GoogleCalendarService.new(@google_account)

  assert_raises(JSON::ParserError) do
    service.fetch_calendars
  end
end

# Quota exceeded scenarios
test "should handle quota exceeded errors" do
  error_response = {
    'error' => {
      'code' => 403,
      'message' => 'Daily Limit Exceeded',
      'errors' => [{'reason' => 'dailyLimitExceeded'}]
    }
  }

  stub_request(:get, %r{googleapis.com/calendar})
    .to_return(status: 403, body: error_response.to_json)

  service = GoogleCalendarService.new(@google_account)

  assert_raises(Google::Apis::ClientError) do
    service.fetch_calendars
  end
end
```

### **4. Business Logic Integration Tests**

```ruby
# End-to-end activity scheduling
test "should schedule activities from suggestions to calendar events" do
  VCR.use_cassette("complete_scheduling_flow") do
    # Create activities with different schedule types
    strict_activity = create(:activity, schedule_type: 'strict',
                            start_time: 2.hours.from_now,
                            end_time: 3.hours.from_now)
    flexible_activity = create(:activity, schedule_type: 'flexible')
    deadline_activity = create(:activity, schedule_type: 'deadline',
                              deadline: 1.week.from_now)

    activities = [strict_activity, flexible_activity, deadline_activity]
    date_range = Date.current..(Date.current + 1.week)

    # Generate scheduling suggestions
    scheduler = ActivitySchedulingService.new(@user, activities)
    suggestions = scheduler.generate_suggestions(date_range)

    assert suggestions.present?
    assert suggestions.any? { |s| s[:type] == 'strict' }
    assert suggestions.any? { |s| s[:type] == 'flexible' }
    assert suggestions.any? { |s| s[:type] == 'deadline' }

    # Create calendar events from suggestions
    results = scheduler.create_calendar_events(suggestions, dry_run: false)
    success_count = results.count { |r| r[:status] == 'created' }

    assert success_count > 0
  end
end

# Conflict detection and resolution
test "should detect and resolve scheduling conflicts" do
  VCR.use_cassette("conflict_resolution") do
    # Set up existing calendar events
    service = GoogleCalendarService.new(@google_account)
    existing_events = service.list_events('primary', Date.current, Date.current + 7.days)

    # Create activity that would conflict
    conflicting_activity = create(:activity,
                                 schedule_type: 'strict',
                                 start_time: existing_events.first['start']['dateTime'],
                                 end_time: existing_events.first['end']['dateTime'])

    scheduler = ActivitySchedulingService.new(@user, [conflicting_activity])
    suggestions = scheduler.generate_suggestions(Date.current..(Date.current + 7.days))

    # Should detect conflict and propose alternative
    conflicted_suggestion = suggestions.find { |s| s[:has_conflict] }
    assert conflicted_suggestion.present?

    # Should have alternative time suggestion
    alternative_suggestion = suggestions.find { |s| s[:conflict_avoided] }
    assert alternative_suggestion.present?
  end
end
```

### **5. Performance & Load Testing**

```ruby
# Batch operations with rate limiting
test "should handle batch event creation with rate limits" do
  activities = create_list(:activity, 50, schedule_type: 'flexible')

  VCR.use_cassette("batch_create_events", allow_playback_repeats: true) do
    service = GoogleCalendarService.new(@google_account)

    # Create events in batches to respect rate limits
    results = activities.in_groups_of(10).map do |activity_batch|
      activity_batch.compact.map do |activity|
        event_data = {
          title: activity.name,
          start_time: 1.hour.from_now,
          end_time: 2.hours.from_now
        }

        begin
          service.create_event('primary', event_data)
          { status: 'created', activity_id: activity.id }
        rescue Google::Apis::RateLimitError
          { status: 'rate_limited', activity_id: activity.id }
        end
      end

      # Add delay between batches
      sleep(1) unless Rails.env.test?
    end.flatten

    created_count = results.count { |r| r[:status] == 'created' }
    rate_limited_count = results.count { |r| r[:status] == 'rate_limited' }

    # Should successfully create most events
    assert created_count > 40
    # Some may be rate limited - that's expected behavior
    assert rate_limited_count < 10
  end
end

# Large calendar data handling
test "should efficiently process large calendar datasets" do
  VCR.use_cassette("large_calendar_fetch") do
    service = GoogleCalendarService.new(@google_account)

    # Fetch events for extended period
    start_date = 6.months.ago.to_date
    end_date = 6.months.from_now.to_date

    events = service.list_events('primary', start_date, end_date)

    # Should handle large result sets efficiently
    assert events.size > 100  # Assuming test account has many events

    # Should properly parse all event data
    events.each do |event|
      assert event['id'].present?
      assert event['start'].present?
      assert event['end'].present?
    end
  end
end
```

## Test Data Management

### **1. Enhanced Fixtures**

```ruby
# test/fixtures/google_accounts.yml
valid_account:
  user: one
  email: test@gmail.com
  google_id: test_google_id_123
  access_token: valid_test_token_encrypted
  refresh_token: valid_refresh_token_encrypted
  expires_at: <%= 1.hour.from_now %>
  calendars: |
    [
      {"id": "primary", "summary": "Test User", "accessRole": "owner"},
      {"id": "work_calendar", "summary": "Work Calendar", "accessRole": "writer"}
    ]

expired_account:
  user: two
  email: expired@gmail.com
  google_id: expired_google_id_456
  access_token: expired_test_token_encrypted
  refresh_token: expired_refresh_token_encrypted
  expires_at: <%= 1.hour.ago %>

revoked_account:
  user: three
  email: revoked@gmail.com
  google_id: revoked_google_id_789
  access_token: nil
  refresh_token: nil
  expires_at: <%= 1.day.ago %>
```

### **2. Test Data Helpers**

```ruby
# test/support/google_test_data.rb
module GoogleTestData
  def sample_calendar_event_detailed(overrides = {})
    {
      'id' => 'test_event_123',
      'summary' => 'Test Event',
      'description' => 'Detailed test event description',
      'start' => {
        'dateTime' => Time.current.iso8601,
        'timeZone' => 'America/Los_Angeles'
      },
      'end' => {
        'dateTime' => (Time.current + 1.hour).iso8601,
        'timeZone' => 'America/Los_Angeles'
      },
      'created' => 1.day.ago.iso8601,
      'updated' => Time.current.iso8601,
      'status' => 'confirmed',
      'attendees' => [
        {'email' => 'attendee@example.com', 'responseStatus' => 'accepted'}
      ],
      'recurrence' => ['RRULE:FREQ=WEEKLY;BYDAY=MO'],
      'reminders' => {
        'useDefault' => false,
        'overrides' => [{'method' => 'email', 'minutes' => 60}]
      }
    }.deep_merge(overrides)
  end

  def sample_calendar_list_detailed
    {
      'items' => [
        {
          'id' => 'primary',
          'summary' => 'Test User',
          'description' => 'Primary calendar for testing',
          'timeZone' => 'America/Los_Angeles',
          'accessRole' => 'owner',
          'defaultReminders' => [{'method' => 'popup', 'minutes' => 10}],
          'selected' => true,
          'primary' => true
        },
        {
          'id' => 'work_calendar_id',
          'summary' => 'Work Calendar',
          'description' => 'Work events and meetings',
          'timeZone' => 'America/Los_Angeles',
          'accessRole' => 'writer',
          'defaultReminders' => [{'method' => 'email', 'minutes' => 60}],
          'selected' => false,
          'primary' => false
        },
        {
          'id' => 'personal_calendar_id',
          'summary' => 'Personal Calendar',
          'accessRole' => 'reader',
          'selected' => false
        }
      ],
      'nextPageToken' => nil
    }
  end

  def sample_events_response_detailed(events_count = 5)
    events = events_count.times.map do |i|
      time_offset = i * 2.hours
      sample_calendar_event_detailed(
        'id' => "event_#{i}",
        'summary' => "Detailed Event #{i + 1}",
        'start' => {
          'dateTime' => (Time.current + time_offset).iso8601,
          'timeZone' => 'America/Los_Angeles'
        },
        'end' => {
          'dateTime' => (Time.current + time_offset + 1.hour).iso8601,
          'timeZone' => 'America/Los_Angeles'
        }
      )
    end

    {
      'items' => events,
      'nextPageToken' => events_count > 10 ? 'next_page_token_123' : nil,
      'timeMin' => Date.current.iso8601,
      'timeMax' => (Date.current + 7.days).iso8601,
      'updated' => Time.current.iso8601,
      'accessRole' => 'owner',
      'defaultReminders' => [{'method' => 'popup', 'minutes' => 10}],
      'summary' => 'Test Calendar'
    }
  end
end
```

## CI/CD Integration

### **1. GitHub Actions Configuration**

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v3

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        bundler-cache: true

    - name: Set up Database
      run: |
        bin/rails db:create
        bin/rails db:migrate
      env:
        DATABASE_URL: postgres://postgres:postgres@localhost/test

    - name: Run tests with VCR cassettes
      run: bundle exec rails test
      env:
        CI: true
        DATABASE_URL: postgres://postgres:postgres@localhost/test
        # Don't set real Google credentials - VCR cassettes contain responses
```

### **2. VCR Configuration for CI**

```ruby
# test/test_helper.rb - VCR configuration
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock

  # In CI, only play back cassettes (never record)
  config.default_cassette_options = {
    record: ENV['CI'] ? :none : :once,
    allow_unused_http_interactions: false
  }

  # Filter sensitive data from recordings
  config.filter_sensitive_data('<GOOGLE_ACCESS_TOKEN>') { ENV['GOOGLE_ACCESS_TOKEN'] }
  config.filter_sensitive_data('<GOOGLE_REFRESH_TOKEN>') { ENV['GOOGLE_REFRESH_TOKEN'] }
  config.filter_sensitive_data('<GOOGLE_CLIENT_ID>') { ENV['GOOGLE_CLIENT_ID'] }
  config.filter_sensitive_data('<GOOGLE_CLIENT_SECRET>') { ENV['GOOGLE_CLIENT_SECRET'] }

  # Allow localhost for Rails server
  config.ignore_localhost = true

  # Don't record OAuth token refresh unless specifically testing
  config.ignore_request do |request|
    request.uri.include?("oauth2.googleapis.com/token") && !VCR.current_cassette&.name&.include?("oauth")
  end
end
```

## Security & Privacy Considerations

### **1. Credential Safety**
- **Never commit real credentials** to version control
- **Use separate test Google Cloud project** with limited scope
- **Filter all sensitive data** from VCR recordings automatically
- **Rotate test credentials** monthly for security
- **Use encrypted credentials** in Rails credentials for any sensitive test data

### **2. Test Data Privacy**
- **Dedicated test Google account** - never use real user data
- **Synthetic test calendar events** that don't contain personal information
- **Clean up test events** after recording VCR cassettes
- **Minimal data recording** - only record necessary API responses

### **3. Access Control**
- **Restricted test OAuth scopes** - only calendar access needed for testing
- **Limited calendar permissions** - use read-only calendars where possible
- **Test account isolation** - separate from any production or development accounts

## Performance Optimization

### **1. Test Execution Speed**
- **Parallel test execution** with appropriate test isolation
- **Cached VCR cassettes** for repeated API interactions
- **Strategic mocking** for unit tests that don't need real API responses
- **Batch test operations** to minimize setup/teardown overhead

### **2. API Efficiency Testing**
```ruby
test "should batch calendar operations efficiently" do
  VCR.use_cassette("efficient_batch_operations") do
    service = GoogleCalendarService.new(@google_account)

    # Measure API call efficiency
    start_time = Time.current

    # Batch multiple operations
    calendars = service.fetch_calendars
    events = service.list_events('primary', Date.current, Date.current + 7.days)

    execution_time = Time.current - start_time

    # Should complete batch operations quickly
    assert execution_time < 5.seconds
    assert calendars.present?
    assert events.present?
  end
end
```

## Maintenance & Troubleshooting

### **1. Regular Maintenance Tasks**
- **Monthly**: Re-record critical VCR cassettes to detect API changes
- **Before releases**: Test with fresh Google account tokens
- **When Google APIs update**: Update cassettes and verify compatibility
- **Quarterly**: Review and clean up unused VCR cassettes

### **2. Common Issues & Solutions**

#### VCR Cassettes Not Playing Back
```bash
# Check VCR configuration
bin/rails runner "puts VCR.configuration.cassette_library_dir"

# Verify cassette exists
ls -la test/vcr_cassettes/google_calendar_events.yml

# Check cassette content
head -20 test/vcr_cassettes/google_calendar_events.yml
```

#### Authentication Failures in Tests
```bash
# Validate Google credentials in test environment
bin/rails runner "
  account = GoogleAccount.first
  puts account.inspect
  puts 'Token expired?' + account.token_expired?.to_s
"

# Test Google API connectivity
bin/rails runner "
  require 'net/http'
  uri = URI('https://www.googleapis.com/calendar/v3/users/me/calendarList')
  puts Net::HTTP.get_response(uri)
"
```

#### Test Data Issues
```bash
# Reset test database and reload fixtures
bin/rails db:test:prepare
bin/rails test test/fixtures/

# Validate fixture data
bin/rails runner -e test "
  puts User.count
  puts GoogleAccount.count
  puts Activity.count
"
```

### **3. Debug Commands**

```bash
# Re-record specific cassette with verbose output
VCR_DEBUG=1 RECORD_VCR=1 bin/rails test test/integration/google_integration_test.rb -n test_should_fetch_calendar_events_with_VCR

# Test Google Calendar service manually
bin/rails runner "
  account = GoogleAccount.first
  service = GoogleCalendarService.new(account)
  puts service.fetch_calendars.inspect
"

# Check WebMock stubs
bin/rails runner -e test "
  puts WebMock::StubRegistry.instance.request_stubs.inspect
"
```

This comprehensive testing approach ensures reliable, maintainable, and efficient Google integration testing while providing excellent coverage of both happy path and error scenarios.