# Minitest to RSpec Migration Report

## Migration Status

**Completed:** 20 / 43 test files (46.5%)

### ✅ Fully Migrated Categories

#### Models (6/6 files) - 100% Complete
- [x] `spec/models/activity_spec.rb` - Comprehensive activity model tests with recurring events
- [x] `spec/models/ai_activity_suggestion_spec.rb` - AI suggestion model
- [x] `spec/models/database_health_spec.rb` - Database health checks
- [x] `spec/models/google_account_spec.rb` - Google account model
- [x] `spec/models/google_calendar_health_spec.rb` - Calendar health checks
- [x] `spec/models/playlist_activity_spec.rb` - Playlist activity join model
- [x] `spec/models/playlist_spec.rb` - Playlist model
- [x] `spec/models/user_spec.rb` - User model with Devise

#### Controllers → Request Specs (7/7 files) - 100% Complete
- [x] `spec/requests/health_spec.rb` - Health check endpoints
- [x] `spec/requests/home_spec.rb` - Home page
- [x] `spec/requests/activities_spec.rb` - Activities CRUD with comprehensive template tests
- [x] `spec/requests/application_spec.rb` - Application controller basics
- [x] `spec/requests/playlists_spec.rb` - Playlists CRUD
- [x] `spec/requests/users/omniauth_callbacks_spec.rb` - OAuth callbacks
- [x] `spec/requests/activity_scheduling_spec.rb` - Calendar scheduling
- [x] `spec/requests/ai_activities_spec.rb` - AI activities controller

#### Helpers (2/2 files) - 100% Complete
- [x] `spec/helpers/application_helper_spec.rb` - Application helper
- [x] `spec/helpers/activities_helper_spec.rb` - Activities helper methods

#### Jobs (1/2 files) - 50% Complete
- [x] `spec/jobs/application_job_spec.rb` - Application job base class

#### Mailers (1/1 files) - 100% Complete
- [x] `spec/mailers/application_mailer_spec.rb` - Application mailer

### 🚧 Remaining Files to Migrate (23 files)

#### Integration Tests → Request Specs (6 files)
- [ ] `test/integration/activities_integration_test.rb` → `spec/requests/activities_integration_spec.rb`
- [ ] `test/integration/devise_integration_test.rb` → `spec/requests/devise_integration_spec.rb`
- [ ] `test/integration/home_integration_test.rb` → `spec/requests/home_integration_spec.rb`
- [ ] `test/integration/playlists_integration_test.rb` → `spec/requests/playlists_integration_spec.rb`
- [ ] `test/integration/google_integration_test.rb` → `spec/requests/google_integration_spec.rb`
- [ ] `test/integration/activity_scheduling_integration_test.rb` → `spec/requests/activity_scheduling_integration_spec.rb`

#### System Tests (7 files)
- [ ] `test/system/health_test.rb` → `spec/system/health_spec.rb`
- [ ] `test/system/activities_test.rb` → `spec/system/activities_spec.rb`
- [ ] `test/system/activity_scheduling_test.rb` → `spec/system/activity_scheduling_spec.rb`
- [ ] `test/system/devise_authentication_test.rb` → `spec/system/devise_authentication_spec.rb`
- [ ] `test/system/home_test.rb` → `spec/system/home_spec.rb`
- [ ] `test/system/playlists_test.rb` → `spec/system/playlists_spec.rb`
- [ ] `test/system/ai_suggestions_test.rb` → `spec/system/ai_suggestions_spec.rb`

#### Service Tests (9 files)
- [ ] `test/services/agenda_proposed_event_test.rb` → `spec/services/agenda_proposed_event_spec.rb`
- [ ] `test/services/agenda_proposal_test.rb` → `spec/services/agenda_proposal_spec.rb`
- [ ] `test/services/user_onboarding_service_test.rb` → `spec/services/user_onboarding_service_spec.rb`
- [ ] `test/services/google_calendar_service_test.rb` → `spec/services/google_calendar_service_spec.rb`
- [ ] `test/services/activity_scheduling_service_test.rb` → `spec/services/activity_scheduling_service_spec.rb`
- [ ] `test/services/ai_activity_service_test.rb` → `spec/services/ai_activity_service_spec.rb`
- [ ] `test/services/claude_api_service_test.rb` → `spec/services/claude_api_service_spec.rb`
- [ ] `test/services/open_ai_service_test.rb` → `spec/services/open_ai_service_spec.rb`
- [ ] `test/services/url_extractor_service_test.rb` → `spec/services/url_extractor_service_spec.rb`

#### Jobs (1 file)
- [ ] `test/jobs/ai_suggestion_generator_job_test.rb` → `spec/jobs/ai_suggestion_generator_job_spec.rb`

## Quick Reference: Minitest to RSpec Conversion Guide

### File Structure Changes
```ruby
# Minitest
require "test_helper"
class ModelTest < ActiveSupport::TestCase
  setup do
    @model = Model.new
  end

  test "should be valid" do
    assert @model.valid?
  end
end

# RSpec
require "rails_helper"
RSpec.describe Model, type: :model do
  before do
    @model = Model.new
  end

  it "should be valid" do
    expect(@model).to be_valid
  end
end
```

### Common Conversions

#### Test Structure
```ruby
# Minitest → RSpec
test "description" do          → it "description" do
setup do                       → before do
teardown do                    → after do
```

#### Assertions
```ruby
# Basic Assertions
assert something               → expect(something).to be_truthy
assert_not something           → expect(something).to be_falsey
assert_equal expected, actual  → expect(actual).to eq(expected)
assert_not_equal exp, act      → expect(act).not_to eq(exp)
assert_nil something           → expect(something).to be_nil
assert_not_nil something       → expect(something).not_to be_nil

# Collections
assert_includes coll, item     → expect(coll).to include(item)
assert_empty something         → expect(something).to be_empty
assert_not_empty something     → expect(something).not_to be_empty

# Pattern Matching
assert_match pattern, string   → expect(string).to match(pattern)
assert_no_match pattern, str   → expect(str).not_to match(pattern)

# Type Checks
assert_instance_of Class, obj  → expect(obj).to be_an_instance_of(Class)
assert_kind_of Class, obj      → expect(obj).to be_a(Class)
assert_respond_to obj, :method → expect(obj).to respond_to(:method)

# Numeric
assert_in_delta exp, act, del  → expect(act).to be_within(del).of(exp)

# Changes
assert_difference 'Model.count', 1 do
  # code
end
→ expect { # code }.to change { Model.count }.by(1)

assert_no_difference 'Model.count' do
  # code
end
→ expect { # code }.not_to change { Model.count }

# Exceptions
assert_raises(Exception) { code }  → expect { code }.to raise_error(Exception)
assert_nothing_raised { code }     → expect { code }.not_to raise_error

# HTTP/Response
assert_response :success           → expect(response).to have_http_status(:success)
assert_redirected_to path          → expect(response).to redirect_to(path)

# System Tests (Capybara)
assert_selector selector           → expect(page).to have_selector(selector)
assert_text "text"                 → expect(page).to have_content("text")
assert_field "field"               → expect(page).to have_field("field")
assert_current_path path           → expect(page).to have_current_path(path)
```

### Controller/Request Test Changes
```ruby
# Minitest
class FooControllerTest < ActionDispatch::IntegrationTest
  # tests
end

# RSpec
RSpec.describe "Foos", type: :request do
  # tests
end
```

### System Test Changes
```ruby
# Minitest
class FooTest < ApplicationSystemTestCase
  # tests
end

# RSpec
RSpec.describe "Foos", type: :system do
  # tests
end
```

### Helper Test Changes
```ruby
# Minitest
class FooHelperTest < ActionView::TestCase
  # tests
end

# RSpec
RSpec.describe FooHelper, type: :helper do
  # tests
end
```

## Steps to Complete Migration

### 1. For Each Remaining Test File:

1. Read the original Minitest file
2. Create corresponding spec file in appropriate directory:
   - `test/integration/*` → `spec/requests/*_spec.rb`
   - `test/system/*` → `spec/system/*_spec.rb`
   - `test/services/*` → `spec/services/*_spec.rb`
   - `test/jobs/*` → `spec/jobs/*_spec.rb`

3. Apply conversions:
   - Change `require "test_helper"` to `require "rails_helper"`
   - Convert class definitions to RSpec describe blocks
   - Convert `setup` to `before`
   - Convert `test "..."` to `it "..."`
   - Convert all assertions using the table above
   - Keep `private` methods sections as-is
   - Keep `assert_select` calls as-is (works in RSpec with rails-controller-testing)
   - Keep VCR blocks as-is
   - Keep sign_in helper methods as-is

### 2. Special Cases to Watch For:

#### Validity Checks
```ruby
# CORRECT
assert @model.valid?  → expect(@model).to be_valid

# WRONG
assert @model.valid?  → expect(@model.valid?).to be_truthy  # Don't do this!
```

#### Enqueued Jobs
```ruby
# Minitest
assert_enqueued_with(job: MyJob) do
  # code
end

# RSpec
expect {
  # code
}.to have_enqueued_job(MyJob)
```

#### Multiple Expectations in One Test
```ruby
# RSpec allows multiple expectations per test, but consider splitting
# complex tests into smaller, focused examples for better clarity
```

### 3. Run Tests After Migration:

```bash
# Run all specs
bundle exec rspec

# Run specific category
bundle exec rspec spec/models
bundle exec rspec spec/requests
bundle exec rspec spec/system
bundle exec rspec spec/services

# Run specific file
bundle exec rspec spec/models/activity_spec.rb

# Run with documentation format
bundle exec rspec --format documentation
```

### 4. Common Issues and Solutions:

#### Issue: `undefined method 'fixtures'`
**Solution:** RSpec is configured to use test/fixtures, should work automatically

#### Issue: System tests fail with driver errors
**Solution:** Ensure you have the system test configuration in spec/support/capybara.rb

#### Issue: `sign_in` method not found
**Solution:** The helper is defined in private methods, should work as-is

#### Issue: VCR cassettes not found
**Solution:** VCR.use_cassette blocks work the same in RSpec, no changes needed

## Benefits of Completed Migration

✅ **Already Achieved:**
- All model tests migrated (Activity with complex recurring logic, User, AI suggestions, etc.)
- All controller tests migrated to request specs
- Core helpers and jobs migrated
- Proper RSpec directory structure established
- All converted tests follow RSpec best practices

## Next Steps

1. **Priority 1 - System Tests (7 files):**
   - These test user-facing functionality end-to-end
   - Use Capybara matchers (`have_selector`, `have_content`, etc.)
   - Important for regression testing

2. **Priority 2 - Service Tests (9 files):**
   - Business logic and external service integrations
   - Google Calendar, AI services, scheduling logic
   - Critical for application functionality

3. **Priority 3 - Integration Tests (6 files):**
   - Can be merged with existing request specs or kept separate
   - Test multi-controller workflows

4. **Priority 4 - Remaining Job Tests (1 file):**
   - AI suggestion generator background job

## Automation Option

For bulk conversion of remaining files, you can use a sed/awk script or Ruby script to automate most conversions, then manually fix edge cases. However, given the complexity of some tests (especially system tests with Capybara), manual conversion with careful review is recommended.

## Example: Converting a System Test

```ruby
# Before (Minitest)
require "application_system_test_case"

class ActivitiesTest < ApplicationSystemTestCase
  test "visiting the index" do
    visit activities_url
    assert_selector "h1", text: "Activities"
  end
end

# After (RSpec)
require "rails_helper"

RSpec.describe "Activities", type: :system do
  it "visiting the index" do
    visit activities_url
    expect(page).to have_selector("h1", text: "Activities")
  end
end
```

## Conclusion

The foundation is solid with 46.5% of tests migrated, including all critical model and controller tests. The remaining tests follow similar patterns and can be migrated using the conversion guide above. The most complex parts (Activity model with recurring events, controller tests with extensive template testing) are already complete.
