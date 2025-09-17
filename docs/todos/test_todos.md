# Test Coverage TODO Items

This document tracks code that is difficult to test or would require low-level infrastructure testing that doesn't provide meaningful value.

## Items Excluded from Coverage Requirements

### 1. ActivitySchedulingController #create
**File**: `app/controllers/activity_scheduling_controller.rb`
**Lines**: Complex Google Calendar API interactions
**Reason**: Requires external API mocking that's better handled with integration tests. The service layer should be tested separately.

### 2. Devise Configuration
**File**: Various Devise-generated code
**Reason**: Third-party library code that's thoroughly tested by the gem maintainers.

### 3. OAuth Callback Handling
**File**: OAuth-related controller methods
**Reason**: Complex external service interactions that require significant test infrastructure. Better covered by end-to-end tests.

### 4. ActiveRecord Callbacks in Edge Cases
**File**: Various model callback chains
**Reason**: Some callback combinations are only triggered in specific production scenarios that are difficult to simulate.

### 5. Error Handling for External Services
**File**: Google Calendar API error handling
**Reason**: Network-dependent error scenarios that are better tested with integration tests.

## Issues to Fix

### Activity Controller Test Failures
- Activity destroy test failing due to fixture state conflicts
- Need to investigate test isolation issues

### Current Coverage Status
As of the last test run, we have **58.42% coverage (347/594 lines)**.

**Current Target**: 58% minimum coverage (achieved)
**Stretch Goal**: 80% coverage

## Coverage Analysis for 80% Target

### Quick Wins (2-3 hours) - 77 lines total
1. **AgendaProposedEvent** (71 lines, 0% → 100%)
   - Pure Ruby value object with no external dependencies
   - High testing value for business logic
   - Easy to test with simple unit tests

2. **ApplicationMailer** (4 lines, 0% → 100%)
   - Rails boilerplate, simple inheritance testing

3. **ApplicationJob** (2 lines, 0% → 100%)
   - Rails boilerplate, basic job queue testing

### Medium Effort (4-6 hours) - 83 additional lines needed
4. **ActivitySchedulingService** (26.4% → 80%+ coverage)
   - Complex business logic requiring fixture calendar events
   - Time zone handling tests
   - Activity suggestion generation tests
   - Integration with Google Calendar (VCR/WebMock already configured)

### Challenging (6-8 hours) - 20 additional lines needed
5. **GoogleCalendarService** (45.3% → 80%+ coverage)
   - Additional VCR cassettes for uncovered methods
   - Error handling scenarios
   - OAuth token refresh edge cases

**Total Estimate**: 12-17 hours to reach 80% coverage (521/594 lines = 87.7%)

## Recommended Implementation Order

1. **Start with AgendaProposedEvent** - Biggest impact (71 lines), lowest effort
2. **Complete ActivitySchedulingService** - Core business logic
3. **Finish GoogleCalendarService** - API integration edge cases
4. **Add boilerplate tests** - ApplicationMailer, ApplicationJob

## Test Categories Completed ✅

- ✅ **User model tests** (100% coverage)
- ✅ **Activity model tests** (100% coverage)
- ✅ **Playlist model tests** (100% coverage)
- ✅ **GoogleAccount model tests** (100% coverage)
- ✅ **PlaylistActivity model tests** (80% coverage)
- ✅ **Controller tests** (Activities: 83.3%, Playlists: 93.3%)
- ✅ **Google integration tests** (OAuth, API stubs, VCR setup)

## Test Categories Needed for 80% Goal

- [ ] **AgendaProposedEvent service tests** (0% → 100%) - **HIGH PRIORITY**
- [ ] **ActivitySchedulingService tests** (26.4% → 80%)
- [ ] **GoogleCalendarService tests** (45.3% → 80%)
- [ ] **ApplicationMailer tests** (0% → 100%)
- [ ] **ApplicationJob tests** (0% → 100%)