# Google Integrations Testing Setup

This document provides a quick start guide for testing Google integrations in the Sidewalks application.

## Quick Start

### 1. **Testing Strategy**

We use a **3-tier testing approach** for Google integrations:

1. **Fast Unit Tests**: Mock/stub Google APIs for quick feedback
2. **VCR Integration Tests**: Record real API interactions for realistic testing
3. **Manual Integration Tests**: End-to-end testing with real Google accounts

### 2. **Tools Installed**

- **VCR**: Records HTTP interactions for playback in tests
- **WebMock**: Stubs HTTP requests for controlled testing
- **Test Helpers**: Pre-built stubs for common Google API responses

### 3. **Current Test Structure**

```
test/
├── integration/google_integration_test.rb    # OAuth and API integration
├── services/google_calendar_service_test.rb  # Service layer testing
├── support/google_test_helper.rb             # Test utilities
└── vcr_cassettes/                            # Recorded API interactions
```

### 4. **Test Examples**

#### Mock-based Testing (Fast)
```ruby
test "should handle calendar list fetching" do
  stub_google_calendar_list  # Mock API response

  service = GoogleCalendarService.new(@google_account)
  # Test service behavior with mocked responses
end
```

#### VCR-based Testing (Realistic)
```ruby
test "should fetch real calendar events" do
  VCR.use_cassette("google_calendar_events") do
    service = GoogleCalendarService.new(@google_account)
    events = service.fetch_events
    assert events.present?
  end
end
```

### 5. **Running Tests**

```bash
# Run all tests (uses mocks/VCR cassettes)
bin/rails test

# Run Google-specific tests
bin/rails test test/integration/google_integration_test.rb
bin/rails test test/services/google_calendar_service_test.rb
```

## Next Steps for Real Google Testing

### 1. **Set Up Test Google Account**

1. Create separate Google Cloud project for testing
2. Enable Calendar API
3. Create OAuth 2.0 credentials
4. Create test Google account with sample calendar data

### 2. **Record VCR Cassettes**

1. Add real credentials to `.env.test`:
   ```bash
   GOOGLE_CLIENT_ID=your_test_client_id
   GOOGLE_CLIENT_SECRET=your_test_client_secret
   GOOGLE_ACCESS_TOKEN=your_test_access_token
   GOOGLE_REFRESH_TOKEN=your_test_refresh_token
   ```

2. Enable recording in tests (remove `skip` statements)

3. Run tests to record real API interactions:
   ```bash
   bin/rails test test/integration/google_integration_test.rb:test_should_fetch_real_calendar_events_with_VCR
   ```

### 3. **Test Categories Available**

- ✅ **OAuth Flow**: User authentication and token management
- ✅ **API Error Handling**: Rate limits, timeouts, invalid responses
- ✅ **Token Refresh**: Automatic token renewal
- 🚧 **Calendar Operations**: List calendars, fetch events, create events
- 🚧 **Batch Operations**: Multiple event creation
- 🚧 **Scheduling Logic**: Activity-to-calendar conversion

### 4. **Security Notes**

- All sensitive data is filtered from VCR recordings
- Test credentials are separate from production
- No real user data is used in testing
- Encryption issues are handled gracefully in test environment

## Benefits of This Approach

1. **Fast Development**: Most tests run without external API calls
2. **Reliable CI/CD**: Tests don't depend on external services
3. **Realistic Testing**: VCR provides real API response formats
4. **Error Coverage**: Easy to test error scenarios with stubs
5. **No API Quotas**: Recorded interactions don't count against limits

## Documentation

- **Comprehensive Guide**: `docs/testing/google_integrations.md`
- **Test Helpers**: `test/support/google_test_helper.rb`
- **Example Tests**: `test/integration/google_integration_test.rb`

This setup provides a robust foundation for testing Google integrations while maintaining fast test execution and avoiding external dependencies in CI/CD pipelines.