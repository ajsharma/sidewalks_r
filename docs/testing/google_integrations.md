# Google Integrations Testing Guide

This guide outlines the best practices for testing Google API integrations in the Sidewalks application.

## Testing Strategy Overview

### 1. **Multi-Layer Approach**

- **Unit Tests**: Test individual methods without external calls
- **VCR Integration Tests**: Record/replay real API interactions
- **Mock Tests**: Fast tests with stubbed responses
- **Manual Integration Tests**: End-to-end testing with real accounts

### 2. **Tools and Setup**

#### VCR (Video Cassette Recorder)
- **Purpose**: Record real HTTP interactions for reliable playback
- **Benefits**: Real API responses, deterministic tests, no API quotas during CI
- **Location**: `test/vcr_cassettes/`

#### WebMock
- **Purpose**: Stub HTTP requests in tests
- **Benefits**: Fast, controlled responses for edge cases
- **Use case**: Error scenarios, timeouts, malformed responses

## Setting Up Test Environment

### 1. **Environment Variables**

Create `.env.test` for testing credentials:

```bash
# Test Google OAuth credentials (use separate app)
GOOGLE_CLIENT_ID=your_test_client_id
GOOGLE_CLIENT_SECRET=your_test_client_secret

# Test account tokens (for recording VCR cassettes)
GOOGLE_ACCESS_TOKEN=your_test_access_token
GOOGLE_REFRESH_TOKEN=your_test_refresh_token
```

### 2. **Test Google Project Setup**

1. Create separate Google Cloud project for testing
2. Enable Calendar API
3. Create OAuth 2.0 credentials
4. Add test callback URLs (localhost:3000)
5. Create test Google account with calendar data

### 3. **Recording VCR Cassettes**

#### Initial Recording Process:

```bash
# 1. Set up real test credentials in .env.test
# 2. Enable recording in test files
# 3. Run tests to record interactions

# Remove cassettes to re-record
rm test/vcr_cassettes/google_calendar_events.yml

# Run specific test to record
bin/rails test test/integration/google_integration_test.rb:test_should_fetch_calendar_events_with_VCR
```

#### Example Recording Test:

```ruby
test "should fetch calendar events with VCR" do
  VCR.use_cassette("google_calendar_events", record: :new_episodes) do
    service = GoogleCalendarService.new(@google_account)
    events = service.fetch_events(Date.current, Date.current + 7.days)

    assert events.present?
    assert events.first.key?('summary')
    assert events.first.key?('start')
  end
end
```

## Test Categories

### 1. **Authentication Tests**

```ruby
# OAuth flow testing
test "should handle Google OAuth callback" do
  VCR.use_cassette("oauth_callback") do
    # Test OAuth token exchange
    # Verify user/account creation
    # Check token storage and encryption
  end
end

# Token refresh testing
test "should refresh expired tokens" do
  VCR.use_cassette("token_refresh") do
    # Test automatic token refresh
    # Verify new tokens are stored
  end
end
```

### 2. **Calendar API Tests**

```ruby
# Calendar listing
test "should fetch user calendars" do
  VCR.use_cassette("calendar_list") do
    service = GoogleCalendarService.new(@google_account)
    calendars = service.fetch_calendars

    assert calendars.any? { |cal| cal['id'] == 'primary' }
  end
end

# Event creation
test "should create calendar events" do
  VCR.use_cassette("create_event") do
    activity = activities(:one)
    service = GoogleCalendarService.new(@google_account)

    result = service.create_event(activity, Time.current + 1.hour)
    assert result['id'].present?
  end
end
```

### 3. **Error Handling Tests**

```ruby
# API errors without VCR
test "should handle rate limiting" do
  stub_request(:get, %r{googleapis.com/calendar})
    .to_return(status: 429, body: '{"error": "Rate limit exceeded"}')

  service = GoogleCalendarService.new(@google_account)
  assert_raises(GoogleCalendarService::RateLimitError) do
    service.fetch_events
  end
end

# Network timeouts
test "should handle timeouts gracefully" do
  stub_request(:get, %r{googleapis.com/calendar})
    .to_timeout

  service = GoogleCalendarService.new(@google_account)
  result = service.fetch_events
  assert_nil result
end
```

### 4. **Business Logic Tests**

```ruby
# Activity scheduling logic
test "should schedule activities correctly" do
  VCR.use_cassette("schedule_activities") do
    scheduler = ActivitySchedulingService.new(@user)

    activities = [@user.activities.first]
    date_range = Date.current..(Date.current + 1.week)

    suggestions = scheduler.generate_suggestions(activities, date_range)
    assert suggestions.present?

    results = scheduler.create_calendar_events(suggestions)
    success_count = results.count { |r| r[:status] == 'created' }
    assert success_count > 0
  end
end
```

## Test Data Management

### 1. **Fixtures for Google Accounts**

```yaml
# test/fixtures/google_accounts.yml
valid_account:
  user: one
  email: test@gmail.com
  google_id: test_google_id_123
  access_token: valid_test_token
  refresh_token: valid_refresh_token
  expires_at: <%= 1.hour.from_now %>

expired_account:
  user: two
  email: expired@gmail.com
  google_id: expired_google_id_456
  access_token: expired_test_token
  refresh_token: expired_refresh_token
  expires_at: <%= 1.hour.ago %>
```

### 2. **Test Calendar Data**

Create consistent test calendar events:

```ruby
# test/support/google_test_data.rb
module GoogleTestData
  def sample_calendar_event
    {
      'id' => 'test_event_123',
      'summary' => 'Test Event',
      'start' => { 'dateTime' => Time.current.iso8601 },
      'end' => { 'dateTime' => (Time.current + 1.hour).iso8601 },
      'description' => 'Test event description'
    }
  end

  def sample_calendar_list
    [
      {
        'id' => 'primary',
        'summary' => 'Test User',
        'accessRole' => 'owner'
      },
      {
        'id' => 'work_calendar_id',
        'summary' => 'Work Calendar',
        'accessRole' => 'writer'
      }
    ]
  end
end
```

## CI/CD Considerations

### 1. **VCR in CI**

```yaml
# .github/workflows/test.yml
- name: Run tests with VCR
  run: bundle exec rails test
  env:
    # Don't set real credentials in CI
    # VCR will use recorded cassettes
    CI: true
```

### 2. **Cassette Management**

```ruby
# Only record in development, playback in CI
VCR.configure do |config|
  config.default_cassette_options = {
    record: ENV['CI'] ? :none : :once
  }
end
```

## Testing Workflow

### 1. **Development Cycle**

1. **Write failing test** with real API calls
2. **Record VCR cassette** with test credentials
3. **Commit cassette** to version control
4. **Tests pass** in CI using cassettes
5. **Update cassettes** when API changes

### 2. **Regular Maintenance**

- **Monthly**: Re-record cassettes to catch API changes
- **Before releases**: Test with fresh tokens
- **When APIs update**: Update cassettes and test new features

## Security Considerations

### 1. **Credential Safety**

- Never commit real credentials to version control
- Use separate test Google project
- Filter sensitive data in VCR recordings
- Rotate test credentials regularly

### 2. **Test Data Privacy**

- Use dedicated test Google account
- Don't test with real user data
- Clean up test calendar events after recording

## Performance Testing

### 1. **API Rate Limits**

```ruby
test "should respect rate limits" do
  # Test batch operations respect Google's limits
  activities = create_list(:activity, 100)

  VCR.use_cassette("batch_create_events") do
    service = GoogleCalendarService.new(@google_account)
    results = service.batch_create_events(activities)

    # Should handle rate limits gracefully
    assert results.all? { |r| r[:status].in?(['created', 'rate_limited']) }
  end
end
```

### 2. **Timeout Handling**

```ruby
test "should handle slow API responses" do
  stub_request(:get, %r{googleapis.com/calendar})
    .to_return(status: 200, body: '{"items": []}', headers: {})
    .with(delay: 5.seconds)

  service = GoogleCalendarService.new(@google_account)

  assert_raises(Timeout::Error) do
    Timeout.timeout(3) { service.fetch_events }
  end
end
```

## Troubleshooting

### Common Issues:

1. **Cassettes not playing back**: Check VCR configuration and cassette paths
2. **Authentication failures**: Verify test credentials and OAuth setup
3. **API changes**: Re-record cassettes when Google updates APIs
4. **Rate limiting**: Use separate test project to avoid quota conflicts

### Debug Commands:

```bash
# Check VCR configuration
bin/rails runner "puts VCR.configuration.cassette_library_dir"

# Validate Google credentials
bin/rails runner "puts GoogleCalendarService.new(GoogleAccount.first).test_connection"

# Re-record specific cassette
rm test/vcr_cassettes/google_calendar_events.yml
bin/rails test test/integration/google_integration_test.rb -n test_should_fetch_calendar_events
```

This comprehensive testing approach ensures reliable Google integration testing while maintaining fast test execution and avoiding API quota issues in CI/CD pipelines.