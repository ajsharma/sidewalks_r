# Testing Best Practices

This document outlines the testing conventions and best practices for the Sidewalks Rails application.

## Overview

Our test suite follows Rails conventions with additional quality standards to ensure comprehensive, reliable testing. We prioritize testing real behavior over mocked interactions to build confidence in our application.

## Testing Philosophy

### No Mocking Policy

**Do not mock internal application code.** 
This includes:
- Models and their methods
- Controllers and services
- Database interactions
- Internal business logic
- Rails framework methods

**Exception: Third-party network requests only**
- External API calls (Google Calendar API, OAuth providers)
- HTTP requests to external services
- Network-dependent operations outside our control

### Why We Avoid Mocking

1. **Real Integration Testing**: Tests verify actual behavior, not assumptions
2. **Refactoring Safety**: Tests remain valid when implementation changes
3. **Database Confidence**: Real database interactions catch edge cases
4. **True Coverage**: SimpleCov shows actual code paths executed

## Test Structure

### Test Types

```
test/
├── controllers/          # Controller integration tests
├── models/              # Model unit tests
├── system/              # End-to-end browser tests
├── helpers/             # View helper tests
├── jobs/                # Background job tests
├── mailers/             # Email testing
└── fixtures/            # Test data
```

### Test Organization

- **One test file per class/module**
- **Descriptive test names** using `test "should do something when condition"`
- **Group related tests** using nested contexts where helpful
- **Setup data in fixtures** for reusable test data

## Running Tests

### Basic Commands
```bash
# Run all tests
bin/rails test

# Run specific test types
bin/rails test:models
bin/rails test:controllers
bin/rails test:system

# Run specific test file
bin/rails test test/models/user_test.rb

# Run specific test method
bin/rails test test/models/user_test.rb -n test_should_validate_email
```

### Code Coverage

SimpleCov automatically generates coverage reports when running tests:

```bash
# Run tests and generate coverage
bin/rails test

# View coverage report
open coverage/index.html
```

**Coverage Goals:**
- Maintain >90% overall coverage
- 100% coverage for critical business logic
- Focus on meaningful tests, not just coverage numbers

## Writing Good Tests

### Model Tests

```ruby
class UserTest < ActiveSupport::TestCase
  test "should validate presence of email" do
    user = User.new(name: "Test User")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should create user with valid attributes" do
    user = User.new(
      name: "Test User",
      email: "test@example.com"
    )
    assert user.valid?
    assert user.save
  end
end
```

### Controller Tests

```ruby
class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)  # Use fixtures
  end

  test "should get index" do
    get users_url
    assert_response :success
    assert_select "h1", "Users"
  end

  test "should create user with valid params" do
    assert_difference("User.count") do
      post users_url, params: {
        user: { name: "New User", email: "new@example.com" }
      }
    end
    assert_redirected_to user_url(User.last)
  end
end
```

### System Tests

```ruby
class UserFlowTest < ApplicationSystemTest
  test "user can sign up and log in" do
    visit new_user_registration_path

    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    click_button "Sign up"

    assert_text "Welcome! You have signed up successfully."
    assert_current_path root_path
  end
end
```

## Testing External Services

When testing code that interacts with external APIs:

### Use VCR for Real HTTP Interactions

```ruby
# In test_helper.rb
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
end

# In your test
class GoogleCalendarTest < ActiveSupport::TestCase
  test "should fetch calendar events" do
    VCR.use_cassette("google_calendar_events") do
      events = GoogleCalendarService.new(@user).fetch_events
      assert events.present?
    end
  end
end
```

### Stubbing Network Requests

Only when VCR isn't suitable:

```ruby
test "should handle API timeout gracefully" do
  stub_request(:get, "https://api.external-service.com/data")
    .to_timeout

  result = ExternalService.fetch_data
  assert_nil result
end
```

## Data Management

### Fixtures Over Factories

Use Rails fixtures for consistent, version-controlled test data:

```yaml
# test/fixtures/users.yml
one:
  name: John Doe
  email: john@example.com
  created_at: <%= 1.day.ago %>

admin:
  name: Admin User
  email: admin@example.com
  admin: true
```

### Database Transactions

Tests automatically run in transactions and roll back. No manual cleanup needed.

```ruby
test "should not persist changes after test" do
  user = User.create!(name: "Test", email: "test@example.com")
  assert User.exists?(user.id)
end
# User is automatically rolled back
```

## Performance Testing

### Use Rails Benchmarking

```ruby
test "should perform search efficiently" do
  assert_performance_under(100) do  # milliseconds
    User.search("john").to_a
  end
end
```

### Memory Testing

```ruby
test "should not leak memory during bulk operations" do
  assert_no_memory_leak([], "1000.times { User.create!(name: 'test', email: 'test@example.com') }") do
    # Memory-intensive operation
  end
end
```

## Common Patterns

### Testing Background Jobs

```ruby
class EmailJobTest < ActiveJob::TestCase
  test "should send welcome email" do
    assert_enqueued_with(job: WelcomeEmailJob) do
      User.create!(name: "Test", email: "test@example.com")
    end
  end

  test "should deliver email with correct content" do
    perform_enqueued_jobs do
      WelcomeEmailJob.perform_later(users(:one))
      assert_emails 1
    end
  end
end
```

### Testing Time-Dependent Code

```ruby
test "should show correct relative time" do
  travel_to Time.zone.parse("2023-01-01 12:00:00") do
    user = User.create!(name: "Test", email: "test@example.com")
    assert_equal "just now", user.created_at_in_words
  end
end
```

### Testing Callbacks and Validations

```ruby
test "should normalize email before save" do
  user = User.new(name: "Test", email: "  TEST@EXAMPLE.COM  ")
  user.save!
  assert_equal "test@example.com", user.email
end
```

## Quality Standards

### Test Quality Checklist

- [ ] Test names clearly describe the behavior
- [ ] Tests are focused on one specific behavior
- [ ] Setup data is minimal and relevant
- [ ] Assertions verify the important outcomes
- [ ] No mocking of internal application code
- [ ] External API calls are stubbed/recorded appropriately
- [ ] Tests run reliably in any order
- [ ] Coverage is meaningful, not just comprehensive

### Code Review Requirements

- All new features must include tests
- Bug fixes must include regression tests
- Controllers tests should verify response codes and content
- Model tests should cover validations and business logic
- System tests should cover critical user workflows

## Debugging Tests

### Common Issues

```bash
# Run tests with verbose output
bin/rails test --verbose

# Debug specific test with binding.pry
# Add `binding.pry` in your test code

# Check for database state issues
bin/rails db:test:prepare

# Run tests without parallel execution
PARALLEL_WORKERS=1 bin/rails test
```

### Test Environment

Tests run against a separate test database that's:
- Automatically managed by Rails
- Reset between test runs
- Isolated from development data

## Continuous Integration

Our CI pipeline runs:
1. `bin/rubocop` - Code quality checks
2. `bin/brakeman` - Security analysis
3. `bin/rails test` - Full test suite with coverage
4. Coverage reports uploaded to CI

## Current Status

**Coverage**: 46.57% (292/627 lines)
**Target**: Maintain >45% with focus on meaningful business logic coverage
**Strategy**: Comprehensive testing of models, controllers, and core business logic while excluding complex external service integrations

Tests must pass with >45% coverage for merging. See `docs/todos/test_todos.md` for detailed coverage strategy and exclusions.
