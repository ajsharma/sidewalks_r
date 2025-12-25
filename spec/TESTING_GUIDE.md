# RSpec Testing Guide

This guide documents best practices for writing fast, reliable tests in this Rails application.

## Performance Metrics

After optimization (2025-12-11):
- **Full test suite**: 15.31 seconds (468 examples)
- **System tests**: 2.14 seconds (32 examples)
- **Model tests**: ~0.5 seconds per file
- **Request tests**: ~0.2 seconds per file

## System Test Configuration

### Driver Strategy

We use **rack_test** as the default driver for system tests because:
- ✅ **10-50x faster** than Selenium/headless Chrome
- ✅ Works without browser dependencies (no chromedriver needed)
- ✅ Sufficient for testing server-rendered HTML and form submissions
- ✅ Works great with Turbo and Stimulus

Only use `:js` tag when you actually need JavaScript:

```ruby
# Fast (rack_test) - PREFER THIS
it "creates a new activity" do
  visit new_activity_path
  fill_in "Name", with: "My Activity"
  click_button "Create Activity"
  expect(page).to have_content "My Activity"
end

# Slow (headless_chrome) - only use for JavaScript tests
it "validates form with JavaScript", :js do
  visit new_activity_path
  fill_in "Name", with: ""
  click_button "Create Activity"  # Triggers JS validation
  expect(page).to have_content "can't be blank"
end
```

### Authentication in System Tests

System tests use a custom `sign_in` helper that goes through the UI:

```ruby
# spec/support/system_helpers.rb provides this
before do
  sign_in user
end

# This is fast with rack_test driver (~50ms per sign-in)
```

**Do not** use Devise test helpers in system tests:
```ruby
# ❌ WRONG - doesn't work with rack_test
include Devise::Test::IntegrationHelpers
sign_in user

# ✅ CORRECT - use SystemHelpers
sign_in user
```

### Database Cleanup

System tests use **table truncation** instead of transactional fixtures because:
- System tests run in a separate server thread
- Transactional fixtures don't share connections between threads

This is automatically configured in `spec/rails_helper.rb`:

```ruby
config.before(:each, type: :system) do
  self.use_transactional_tests = false
end

config.after(:each, type: :system) do
  # TRUNCATE CASCADE handles foreign key constraints
  tables = ActiveRecord::Base.connection.tables - ['ar_internal_metadata', 'schema_migrations']
  tables.each do |table|
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE")
  end
end
```

## Factory Best Practices

### Valid Factory Data

Always ensure factory data meets model validations:

```ruby
# ❌ WRONG - max_frequency_days must be one of: 1, 30, 60, 90, 180, 365, nil
factory :activity do
  max_frequency_days { 7 }  # INVALID!
end

# ✅ CORRECT
factory :activity do
  max_frequency_days { 30 }  # Valid value
end
```

### Performance Tips

```ruby
# Prefer build_stubbed for tests that don't need database persistence
let(:user) { build_stubbed(:user) }

# Use create only when you need database persistence
let(:activity) { create(:activity, user: user) }

# Use create_list for multiple records
let(:activities) { create_list(:activity, 5, user: user) }
```

## Common Pitfalls and Solutions

### 1. System Tests Hanging or Timing Out

**Symptom**: Tests hang indefinitely or timeout after 2-3 minutes

**Cause**: Missing or improperly configured browser driver (chromedriver)

**Solution**: Use `rack_test` driver by default (already configured in this project)

```ruby
# spec/support/capybara.rb
RSpec.configure do |config|
  # rack_test by default (fast, no browser needed)
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  # headless_chrome only for :js tagged tests
  config.before(:each, type: :system, js: true) do
    driven_by :headless_chrome  # Requires: brew install --cask chromedriver
  end
end
```

### 2. "Could not find a valid mapping" Error

**Symptom**: `RuntimeError: Could not find a valid mapping for #<User ...>`

**Cause**: Devise::Test::IntegrationHelpers doesn't work with rack_test driver

**Solution**: Use SystemHelpers module instead (already configured)

**Additional Note**: In Rails 8, this error can also occur due to lazy route loading combined with VCR. The test suite now forces route loading at startup to prevent this issue.

### 3. VCR and External HTTP Calls

**Pattern**: Specs that make external HTTP requests should use VCR cassettes

**How it works**: VCR automatically wraps service specs and activity_scheduling specs. For other specs making external HTTP calls, tag them with `vcr: true`.

```ruby
# Service specs automatically get VCR wrapping
RSpec.describe RssParserService, type: :service do
  # VCR cassettes auto-recorded/replayed
end

# Request specs need explicit tag if they make external HTTP calls
RSpec.describe "ExternalAPI", type: :request, vcr: true do
  # VCR cassettes auto-recorded/replayed
end

# Most request specs don't make external HTTP calls and don't need VCR
RSpec.describe "Events", type: :request do
  # No VCR wrapper (faster tests)
end
```

**Note**: VCR is configured with `allow_http_connections_when_no_cassette: false`, so any spec that makes an external HTTP call without a cassette will fail, providing CI safety.

### 4. "Capybara::NotSupportedByDriverError: accept_modal"

**Symptom**: Tests fail with `accept_confirm` or `dismiss_confirm`

**Cause**: JavaScript modals don't work with rack_test driver

**Solution**: Tag test with `:js` or refactor to not use modals

```ruby
# Option 1: Tag test with :js
it "deletes with confirmation", :js do
  accept_confirm do
    click_link "Delete"
  end
end

# Option 2: Use data-turbo-confirm attribute (no :js needed)
# In view: link_to "Delete", path, data: { turbo_confirm: "Are you sure?" }
it "deletes with confirmation" do
  click_link "Delete"
  # Turbo handles confirmation, no JavaScript driver needed
end
```

### 4. Factory Validation Errors

**Symptom**: `ActiveRecord::RecordInvalid: Validation failed`

**Cause**: Factory data doesn't match model validations

**Solution**: Check model validations and update factory

```ruby
# Check model: app/models/activity.rb
validates :max_frequency_days, inclusion: { in: [1, 30, 60, 90, 180, 365, nil] }

# Update factory: spec/factories/activities.rb
factory :activity do
  max_frequency_days { 30 }  # Must be one of the allowed values
end
```

### 5. Slow Test Suite

**Symptom**: Tests take minutes to run

**Common causes and solutions**:

1. **Using JavaScript driver unnecessarily**
   - Solution: Remove `:js` tag from tests that don't need it
   - Use `bin/analyze-slow-tests` to find slow tests

2. **Creating too much test data**
   - Solution: Use `build_stubbed` instead of `create`
   - Create minimal data needed for each test

3. **Not using database transactions**
   - Solution: Use `config.use_transactional_fixtures = true` (default for non-system tests)

4. **N+1 queries in tests**
   - Solution: Use `includes` or `preload` in test setup
   - Bullet gem will warn you about N+1 queries in development

## Test Analysis Tools

### Analyze Slow Tests

```bash
# Find tests slower than 1 second
bin/analyze-slow-tests

# Find tests slower than 0.5 seconds
bin/analyze-slow-tests --threshold 0.5

# Output as JSON
bin/analyze-slow-tests --format json
```

This tool will:
- Profile all tests and show the slowest ones
- Group results by test type (system, request, model, etc.)
- Provide recommendations based on test patterns

### RSpec Profiling

```bash
# Profile top 20 slowest tests
bundle exec rspec --profile 20

# Profile specific file
bundle exec rspec spec/system/activities_spec.rb --profile
```

## CI/CD Considerations

### GitHub Actions / CI Environment

System tests in CI should use the same configuration:

```yaml
# .github/workflows/ci.yml
- name: Run tests
  run: bundle exec rspec
  env:
    RAILS_ENV: test
    # rack_test driver works without browser in CI
```

### Parallel Test Execution

For even faster CI builds, consider parallel test execution:

```bash
# Run tests in parallel (requires parallel_tests gem)
bundle exec parallel_rspec spec/
```

## Summary of Best Practices

1. ✅ **Use rack_test driver** for system tests by default
2. ✅ **Only use :js tag** when JavaScript is actually needed
3. ✅ **Use SystemHelpers** for authentication in system tests
4. ✅ **Ensure factory data** matches model validations
5. ✅ **Use build_stubbed** when you don't need database persistence
6. ✅ **Run bin/analyze-slow-tests** regularly to catch performance regressions
7. ✅ **Keep tests focused** - one concept per test
8. ✅ **Use request specs** for API testing instead of system specs when possible

## Additional Resources

- [RSpec Best Practices](https://rspec.info/documentation/6-1/rspec-rails/)
- [Capybara Documentation](https://rubydoc.info/github/teamcapybara/capybara/master)
- [Factory Bot Best Practices](https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md)
- [Test Performance Guide](https://thoughtbot.com/blog/how-we-test-rails-applications)
