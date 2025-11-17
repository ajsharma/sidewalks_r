# PRD: Power User Scheduling Features

**Document Version:** 1.0
**Created:** 2025-11-16
**Author:** Product Team
**Status:** Draft - Planning Phase

---

## Executive Summary

### Problem Statement

The Sidewalks activity scheduling system currently lacks two critical features that prevent it from handling real-world scheduling scenarios:

1. **No Recurring Activity Support**: Users cannot create activities for events that repeat on a schedule with specific times (e.g., "Alameda Point Antiques Faire - 1st Sunday every month, 9am-12pm"). The current three schedule types (flexible, strict, deadline) only support one-time activities or flexible activities without specific times.

2. **No Activity Window vs Attendance Duration**: The system cannot distinguish between an activity's total duration and a user's planned attendance. For example, a 3-hour event where the user only plans to attend for 2 hours cannot be properly represented or scheduled.

### Current System Limitations

**Schedule Types:**
- **Flexible**: Can happen anytime, uses suggested days/times but no specific time windows
- **Strict**: Single occurrence with exact start/end times
- **Deadline**: Task with a due date

**Duration Handling:**
- Flexible and deadline activities use a hardcoded 60-minute duration for ALL activities
- Strict activities use start_time/end_time as the exact activity time with no flexibility
- No concept of "event runs X hours, but I'll only attend for Y hours" (distinguishing event duration from user's participation)

### Proposed Solution

Add two major features:

1. **Recurring Activity System**: Comprehensive support for creating activities for recurring events with strict times, including complex patterns like "1st Sunday of every month", "every other Tuesday", "last Friday of month", etc.

2. **Event Window vs Attendance Duration**: Add `duration_minutes` field and event window logic to distinguish between when an event is happening (event window) and how long the user plans to participate (attendance duration).

### Success Criteria

- Users can create recurring activities with AI auto-detection from text/URLs
- Scheduling service correctly generates occurrences for recurring activities
- Users can specify attendance duration separately from event duration
- AI correctly detects recurring patterns with >90% accuracy
- All edge cases handled (leap years, month boundaries, DST, etc.)
- Full test coverage (>85%) including edge cases
- No breaking changes to existing flexible/strict/deadline activities

---

## User Stories

### Recurring Activities

**Story 1: User creates activity for weekly recurring event**
> As a user, when I input "Yoga class every Monday at 6pm for 1 hour", the AI should automatically detect this is a weekly recurring event, create an activity with the recurrence pattern "every Monday", set the time to 6pm-7pm, and generate occurrences for future Mondays in my scheduling range.

**Story 2: User creates activity for monthly recurring event by position**
> As a user, when I input "Alameda Point Antiques Faire - 1st Sunday every month from 9am-12pm", the AI should detect this is a monthly recurring event that happens on the 1st Sunday, create an activity with event window 9am-12pm, and generate occurrences for the 1st Sunday of each future month.

**Story 3: User edits recurring activity**
> As a user, I should be able to edit a recurring activity's pattern, time, or duration, and the system should regenerate future occurrences based on the updated pattern.

**Story 4: User sets end date for recurring activity**
> As a user, I should be able to specify when a recurring activity ends (e.g., "Weekly yoga class ending in March 2026"), and the system should stop generating occurrences after that date.

### Event Window vs Attendance Duration

**Story 5: User attends part of a long event**
> As a user, when I create an activity "Alameda Point Antiques Faire - 9am to 12pm, I'll go for 2 hours", the system should know the event window is 9am-12pm (when the event is happening) but only block 2 hours in my schedule (my attendance duration), and should be able to schedule my attendance anytime within that 9am-12pm window.

**Story 6: Flexible activity with custom duration**
> As a user, when I create a flexible activity "Morning walk", I should be able to specify it takes 30 minutes (not the default 60 minutes), and the scheduling service should block 30 minutes when scheduling this activity.

**Story 7: AI detects duration from text**
> As a user, when I input "Go to farmers market for an hour", the AI should detect both the activity and that I plan to spend 1 hour (60 minutes) there, even if the farmers market is open for multiple hours.

---

## Current System Analysis

### Database Schema (Activities Table)

**Current fields:**
```ruby
# Time-related fields
t.datetime :start_time          # For strict: exact start time
t.datetime :end_time            # For strict: exact end time
t.datetime :deadline            # For deadline: due date

# Flexible scheduling hints
t.string :suggested_time_of_day # "morning", "afternoon", "evening", "night"
t.integer :suggested_days_of_week, array: true  # [0,1,2,3,4,5,6]
t.integer :suggested_months, array: true        # [1,2,3..12]
t.integer :max_frequency_days   # How often to repeat (1,30,60,90,180,365)

# Schedule type
t.string :schedule_type         # "flexible", "strict", "deadline"
```

**Missing fields:**
- No recurrence pattern/rule
- No duration field (uses hardcoded 60 minutes)
- No event window vs attendance duration distinction
- No recurrence start/end dates
- No way to specify "1st Sunday" or "last Friday" patterns

### Activity Model

**Current schedule types** (app/models/activity.rb:11-12):
```ruby
SCHEDULE_TYPES = %w[flexible strict deadline].freeze
```

**Validations:**
- Strict activities must have both start_time and end_time (lines 195-198)
- Duration cannot exceed 12 hours (lines 176-179)
- end_time must be after start_time

**No support for:**
- Recurring activities (for events that repeat)
- Custom duration per activity
- Event windows with flexible attendance (event runs X hours, user attends Y hours)

### Scheduling Service

**Current behavior** (app/services/activity_scheduling_service.rb):

**Flexible activities:**
- Uses hardcoded `preferred_duration: 60.minutes` (line 191)
- Calculates: `end_time = suggested_time + 60.minutes` (line 373)
- Does NOT use activity's start_time/end_time fields

**Strict activities:**
- Uses exact `start_time` and `end_time` from activity (lines 205-224)
- Generates a single occurrence if it falls within date range
- No recurring logic

**Deadline activities:**
- Uses hardcoded `preferred_duration: 60.minutes` (line 309)
- Schedules 1-3 days before deadline

**Problem:** All flexible and deadline activities get 60-minute blocks regardless of actual activity duration.

### AI Services

**Claude API Service** (app/services/claude_api_service.rb):

Current system prompt (lines 31-34):
```
Scheduling guidelines:
- "flexible": Activities that can happen any time
- "strict": Time-sensitive events with specific start/end times
- "deadline": Tasks with a due date
```

**Missing:**
- No instructions for detecting recurring patterns
- No output format for recurrence rules
- No duration extraction from text

**OpenAI Service** (app/services/open_ai_service.rb):
- Same limitations as Claude service
- No recurrence detection

### View Layer

**AI Suggestion Form** (app/views/ai_activities/show.html.erb):

Schedule type dropdown (lines 70-77):
```erb
<%= form.select :schedule_type,
  options_for_select([
    ['Flexible - Can happen anytime', 'flexible'],
    ['Strict - Specific date/time', 'strict'],
    ['Deadline - Must complete by date', 'deadline']
  ], suggested_data[:schedule_type])
%>
```

**Missing:**
- No recurring event option
- No recurrence pattern builder UI
- No duration input field
- No event window inputs

**Activity Form** (app/views/activities/_form.html.erb):
- Same limitations as AI suggestion form
- Start/End time fields only shown for strict type (lines 45-56)

---

## Proposed Solution

### Feature 1: Recurring Activity System

#### Overview

Add comprehensive support for creating activities that represent recurring events, using iCalendar RRULE format (RFC 5545) for maximum flexibility and industry standard compatibility.

#### Supported Recurrence Patterns

1. **Daily**: Every N days
   - Example: "every day", "every 3 days"

2. **Weekly**: Every N weeks on specific days
   - Example: "every Monday", "every Monday and Wednesday", "every other Tuesday"

3. **Monthly (by date)**: Specific date each month
   - Example: "15th of every month", "1st and 15th of every month"

4. **Monthly (by position)**: Nth occurrence of weekday
   - Example: "1st Sunday every month", "2nd and 4th Tuesday", "last Friday of month"

5. **Yearly**: Specific date each year
   - Example: "June 15th every year", "2nd Monday of March every year"

6. **Custom intervals**: Every N weeks/months/years
   - Example: "every 2 weeks", "every 3 months"

#### Database Schema Changes

**Add new fields to activities table:**

```ruby
# Migration: add_recurring_events_to_activities
class AddRecurringEventsToActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :activities, :recurrence_rule, :jsonb
    add_column :activities, :recurrence_start_date, :date
    add_column :activities, :recurrence_end_date, :date
    add_column :activities, :occurrence_time_start, :time
    add_column :activities, :occurrence_time_end, :time

    add_index :activities, :recurrence_rule, using: :gin
    add_index :activities, :recurrence_start_date
    add_index :activities, :recurrence_end_date
  end
end
```

**Field descriptions:**

- `recurrence_rule` (jsonb): Stores iCalendar-style RRULE for maximum flexibility
  ```json
  {
    "freq": "WEEKLY",           // DAILY, WEEKLY, MONTHLY, YEARLY
    "interval": 1,              // Every N weeks/months/etc
    "byday": ["MO", "WE"],      // Days of week (SU,MO,TU,WE,TH,FR,SA)
    "bymonthday": [1, 15],      // Days of month (1-31)
    "bysetpos": [1, -1],        // Position in month (1=first, -1=last)
    "count": 10,                // Max occurrences (optional)
    "until": "2026-12-31"       // End date (optional)
  }
  ```

- `recurrence_start_date` (date): When recurrence begins
- `recurrence_end_date` (date, nullable): When recurrence stops (null = indefinite)
- `occurrence_time_start` (time): Time component for recurring events (e.g., "09:00:00")
- `occurrence_time_end` (time): End time component (e.g., "12:00:00")

**Examples:**

**Weekly - "Every Monday at 6pm for 1 hour":**
```json
{
  "recurrence_rule": {"freq": "WEEKLY", "interval": 1, "byday": ["MO"]},
  "recurrence_start_date": "2025-11-18",
  "recurrence_end_date": null,
  "occurrence_time_start": "18:00:00",
  "occurrence_time_end": "19:00:00"
}
```

**Monthly by position - "1st Sunday every month, 9am-12pm":**
```json
{
  "recurrence_rule": {"freq": "MONTHLY", "interval": 1, "byday": ["SU"], "bysetpos": [1]},
  "recurrence_start_date": "2025-12-01",
  "recurrence_end_date": null,
  "occurrence_time_start": "09:00:00",
  "occurrence_time_end": "12:00:00"
}
```

**Every other Tuesday:**
```json
{
  "recurrence_rule": {"freq": "WEEKLY", "interval": 2, "byday": ["TU"]},
  "recurrence_start_date": "2025-11-18",
  "recurrence_end_date": null,
  "occurrence_time_start": "14:00:00",
  "occurrence_time_end": "15:00:00"
}
```

### Feature 2: Event Window vs Attendance Duration

#### Overview

Add the ability to distinguish between:
1. **Event window**: When the real-world event is happening (e.g., farmers market runs 9am-12pm)
2. **Attendance duration**: How long the user's activity/participation will be (e.g., user attends for 2 hours)

This enables scheduling flexibility for events like farmers markets, fairs, open houses, etc., where the event runs for hours but the user's activity (their attendance) only spans a portion of that time.

#### Database Schema Changes

**Add new field to activities table:**

```ruby
# Migration: add_duration_to_activities
class AddDurationToActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :activities, :duration_minutes, :integer

    # Set default duration for existing flexible/deadline activities
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE activities
          SET duration_minutes = 60
          WHERE schedule_type IN ('flexible', 'deadline')
        SQL
      end
    end
  end
end
```

**Field description:**

- `duration_minutes` (integer): How long the user's activity/participation takes in minutes
  - For **flexible** activities: How long the activity takes (replaces hardcoded 60 minutes)
  - For **deadline** activities: How long the task takes to complete
  - For **strict** activities with event windows: User's planned attendance duration (may be less than the event's total duration)
  - For **recurring_strict** activities: User's planned attendance duration per occurrence (may be less than the event's total duration)
  - Example values: 30 (short walk), 60 (lunch), 90 (movie), 120 (event attendance), 180 (workshop), 240 (full activity)

---

## Implementation Phases

### Phase 1: Database Migrations (Week 1)

**Tasks:**
- [ ] Create migration: `add_recurring_events_to_activities`
  - Add recurrence_rule (jsonb)
  - Add recurrence_start_date (date)
  - Add recurrence_end_date (date, nullable)
  - Add occurrence_time_start (time)
  - Add occurrence_time_end (time)
  - Add indexes
- [ ] Create migration: `add_duration_to_activities`
  - Add duration_minutes (integer)
  - Backfill existing flexible/deadline activities with 60 minutes
- [ ] Run migrations
- [ ] Update db/schema.rb

**Deliverables:**
- Migrations run successfully in development
- Schema updated with all new fields

### Phase 2: Model Changes (Week 1-2)

**Tasks:**
- [ ] Update Activity model
  - Add `recurring_strict` to SCHEDULE_TYPES
  - Add validations for recurring fields
  - Add validations for duration_minutes
  - Implement `next_occurrence(from_date)` method
  - Implement `occurrences_in_range(start_date, end_date)` method
  - Implement `matches_recurrence_pattern?(date)` method
  - Implement pattern matching helpers (daily, weekly, monthly, yearly)
  - Add `effective_duration_minutes` method
  - Add `time_windowed?` check
  - Add `time_window` method
- [ ] Add comprehensive unit tests for all recurrence methods
  - Test daily patterns (every day, every N days)
  - Test weekly patterns (specific days, every N weeks)
  - Test monthly by date (15th of month, 1st and 15th)
  - Test monthly by position (1st Sunday, last Friday, 2nd Tuesday)
  - Test yearly patterns
  - Test edge cases (leap years, Feb 29, month boundaries)
  - Test duration calculations
  - Test time window logic

**Deliverables:**
- All Activity model tests pass
- Code coverage >90% for new methods
- Edge cases documented and tested

### Phase 3: AI Service Updates (Week 2-3)

**Tasks:**
- [ ] Update ClaudeApiService
  - Add recurring event guidelines to system prompt
  - Add duration extraction guidelines
  - Update expected JSON response format
  - Add pattern detection logic
  - Test with various input formats
- [ ] Update OpenAiService
  - Same updates as Claude service
  - Ensure consistent behavior between providers
- [ ] Create test fixtures for AI responses
- [ ] Add integration tests for pattern detection
  - "every Monday at 6pm"
  - "1st Sunday every month"
  - "last Friday of month"
  - "every other Tuesday"
  - "Event 9am-12pm, I'll go for 2 hours"

**Deliverables:**
- AI correctly detects >90% of test patterns
- Both Claude and OpenAI services have consistent behavior
- Pattern detection tests pass

### Phase 4: Scheduling Service (Week 3-4)

**Tasks:**
- [ ] Add `suggest_recurring_strict_schedule` method
  - Generate occurrences in date range
  - Check for conflicts
  - Build reasoning strings
- [ ] Update `suggest_flexible_schedule` to use duration_minutes
- [ ] Update `suggest_deadline_schedule` to use duration_minutes
- [ ] Add `suggest_windowed_strict_schedule` for time-windowed events
- [ ] Add conflict detection helpers
- [ ] Add recurrence pattern description helpers
- [ ] Update main `generate_activity_suggestions` method
- [ ] Add comprehensive tests
  - Test recurring event scheduling
  - Test time-windowed event scheduling
  - Test duration-based flexible scheduling
  - Test conflict detection
  - Test edge cases

**Deliverables:**
- Scheduling service correctly generates occurrences
- Time windows work correctly
- Duration-based scheduling works for all types
- All tests pass

### Phase 5: View Updates (Week 4-5)

**Tasks:**
- [ ] Create Stimulus controllers
  - schedule_type_controller.js (show/hide fields)
  - recurrence_controller.js (update recurrence UI)
- [ ] Update AI suggestion form (ai_activities/show.html.erb)
  - Add recurring_strict to schedule type dropdown
  - Add recurrence pattern builder UI
  - Add duration field for all types
  - Wire up Stimulus controllers
- [ ] Update activity form (activities/_form.html.erb)
  - Same updates as AI suggestion form
- [ ] Update activity show view (activities/show.html.erb)
  - Display recurrence pattern
  - Display next occurrences
  - Display time window info
  - Display duration info
- [ ] Update activity index view (activities/index.html.erb)
  - Add recurring event indicators
- [ ] Add CSS styling for new fields
- [ ] Test UI in all browsers

**Deliverables:**
- All forms work correctly
- Recurrence pattern builder is intuitive
- Duration fields are clear
- Mobile-responsive design
- Cross-browser compatible

### Phase 6: Controller Updates (Week 5)

**Tasks:**
- [ ] Update AiActivitiesController
  - Update strong params to permit recurrence fields
  - Update strong params to permit duration_minutes
  - Update `accept` action to handle recurrence_rule
  - Add validation error handling
- [ ] Update ActivitiesController
  - Update strong params
  - Handle recurrence fields in create/update
  - Add error handling
- [ ] Add controller tests
  - Test creating recurring activities
  - Test updating recurring activities
  - Test validation errors
  - Test duration updates

**Deliverables:**
- Controllers handle all new fields correctly
- Validation errors displayed properly
- All controller tests pass

### Phase 7: Comprehensive Testing (Week 6)

**Tasks:**
- [ ] Add test fixtures
  - Weekly recurring event
  - Monthly by date (15th)
  - Monthly by position (1st Sunday)
  - Last Friday of month
  - Yearly event
  - Time-windowed event
  - Activities with various durations
- [ ] Add integration tests
  - Full flow: AI input → suggestion → acceptance → scheduling
  - Test recurring event generation
  - Test time window scheduling
  - Test conflict handling
- [ ] Add system tests
  - Create recurring event via UI
  - Edit recurrence pattern
  - View generated occurrences
  - Schedule time-windowed event
- [ ] Test edge cases
  - Leap year (Feb 29)
  - Month boundaries (Jan 31 → Feb)
  - DST transitions
  - Invalid patterns (5th Monday when month has 4)
  - Conflicts with existing events
- [ ] Performance testing
  - Generate 100+ occurrences
  - Scheduling with many existing events
  - Database query optimization

**Deliverables:**
- Test coverage >85%
- All edge cases handled correctly
- Performance acceptable (<1s for 100 occurrences)
- No N+1 queries

### Phase 8: Documentation (Week 6)

**Tasks:**
- [ ] Update CLAUDE.md
  - Document recurring event creation
  - Document duration fields
  - Provide examples
- [ ] Add inline documentation (YARD)
  - Document all new methods
  - Add examples
  - Document parameters and return values
- [ ] Update user-facing help text in views
  - Explain recurrence patterns
  - Explain time windows
  - Provide examples
- [ ] Create migration guide
  - How existing data is handled
  - Any manual steps required
- [ ] Add troubleshooting guide
  - Common issues
  - How to fix invalid recurrence patterns

**Deliverables:**
- All code documented (YARD >95%)
- User-facing documentation complete
- Migration guide available

---

## Success Metrics

### AI Pattern Detection Accuracy

**Target: >90% accuracy**

Test with 100 diverse recurring event descriptions (where users create activities for these events):
- Weekly patterns (every Monday yoga class, every Mon/Wed/Fri gym, etc.)
- Monthly by date (team meeting 15th of month, payday lunch 1st and 3rd Friday)
- Monthly by position (farmers market 1st Sunday, book club 2nd Tuesday, happy hour last Friday)
- Intervals (bi-weekly sprint planning, quarterly board meeting)
- Duration extraction (go for 2 hours, 30 min call, attend half the event)

### Scheduling Performance

**Targets:**
- Generate 100 occurrences for recurring activity: <1 second
- Find available time slot within 3-hour event window: <200ms
- Schedule day with 10 existing activities: <500ms

### Test Coverage

**Target: >85% code coverage**

Focus areas:
- Model methods (recurrence logic, pattern matching)
- Scheduling service (occurrence generation, conflict detection)
- Controllers (parameter handling, validation)
- View helpers
- Edge cases

### User Experience

**Qualitative metrics:**
- Recurrence pattern builder is intuitive (user testing)
- Duration fields are clear and understandable
- AI correctly interprets >90% of natural language inputs
- Error messages are helpful and actionable

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Edge case bugs in recurrence logic | High | High | Comprehensive test coverage, especially edge cases (leap years, month boundaries) |
| Performance issues generating many occurrences | Medium | Medium | Add database indexes, limit occurrence generation to reasonable ranges, pagination |
| AI pattern detection inaccuracies | Medium | Medium | Extensive training examples, fallback to manual entry, user can always edit |
| Timezone/DST complications | Medium | High | Start with single timezone, document limitations, plan for future enhancement |
| Confusion between event window and attendance duration | Medium | High | Clear UI labels, help text ("Event runs 9am-12pm, you'll attend for 2 hours"), visual examples |

### User Experience Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Recurrence UI too complex | Medium | High | User testing, iterative design, progressive disclosure |
| Duration concept confusing | Low | Medium | Clear labels, help text, examples |
| Too many form fields overwhelming | Medium | Medium | Use progressive disclosure, smart defaults from AI |

---

## Appendix: Example Use Cases

### Use Case 1: Weekly Yoga Class

**User Input**: "Yoga class every Monday at 6pm for 1 hour"

**Interpretation**: User wants to create an activity for a recurring event (yoga class happens every Monday). The event runs for a specific time each week.

**AI Detection**:
```json
{
  "name": "Yoga Class",
  "schedule_type": "recurring_strict",
  "recurrence_rule": {"freq": "WEEKLY", "interval": 1, "byday": ["MO"]},
  "occurrence_time_start": "18:00",
  "occurrence_time_end": "19:00",
  "duration_minutes": 60
}
```

**Generated Occurrences** (next 4 weeks):
- Mon, Nov 18, 2025 6:00 PM - 7:00 PM
- Mon, Nov 25, 2025 6:00 PM - 7:00 PM
- Mon, Dec 2, 2025 6:00 PM - 7:00 PM
- Mon, Dec 9, 2025 6:00 PM - 7:00 PM

### Use Case 2: Alameda Point Antiques Faire

**User Input**: "Alameda Point Antiques Faire - 1st Sunday every month from 9am-12pm, I'd go for 2 hours"

**Interpretation**: User wants to create an activity for a recurring event (the faire happens 1st Sunday every month). The **event** runs 9am-12pm (3 hour window), but the user's **activity** (their attendance) is only 2 hours within that window.

**AI Detection**:
```json
{
  "name": "Alameda Point Antiques Faire",
  "schedule_type": "recurring_strict",
  "recurrence_rule": {"freq": "MONTHLY", "interval": 1, "byday": ["SU"], "bysetpos": [1]},
  "occurrence_time_start": "09:00",
  "occurrence_time_end": "12:00",
  "duration_minutes": 120,
  "reasoning": "Event runs 9am-12pm (3 hours), user plans 2-hour visit"
}
```

**Scheduling Behavior**:
- **Event window** (when faire is open): 9:00 AM - 12:00 PM (3 hours)
- **User's activity duration** (attendance): 2 hours
- Scheduler finds 2-hour slot for the user's activity within the event window:
  - Option 1: 9:00 AM - 11:00 AM (attend early)
  - Option 2: 10:00 AM - 12:00 PM (attend late)
  - Option 3: 9:30 AM - 11:30 AM (attend middle, if other options have conflicts)

**Generated Activity Occurrences** (user's scheduled attendance):
- Sun, Dec 1, 2025 9:00 AM - 11:00 AM (2-hour attendance at faire)
- Sun, Jan 5, 2026 9:00 AM - 11:00 AM (2-hour attendance at faire)
- Sun, Feb 1, 2026 9:00 AM - 11:00 AM (2-hour attendance at faire)

### Use Case 3: Book Club - 2nd Thursday

**User Input**: "Book club 2nd Thursday of each month at 7pm"

**AI Detection**:
```json
{
  "name": "Book Club",
  "schedule_type": "recurring_strict",
  "recurrence_rule": {"freq": "MONTHLY", "interval": 1, "byday": ["TH"], "bysetpos": [2]},
  "occurrence_time_start": "19:00",
  "occurrence_time_end": "21:00",
  "duration_minutes": 120
}
```

**Generated Occurrences**:
- Thu, Nov 14, 2025 7:00 PM - 9:00 PM
- Thu, Dec 12, 2025 7:00 PM - 9:00 PM
- Thu, Jan 9, 2026 7:00 PM - 9:00 PM

### Use Case 4: Monthly Happy Hour - Last Friday

**User Input**: "Last Friday happy hour at 5pm"

**AI Detection**:
```json
{
  "name": "Happy Hour",
  "schedule_type": "recurring_strict",
  "recurrence_rule": {"freq": "MONTHLY", "interval": 1, "byday": ["FR"], "bysetpos": [-1]},
  "occurrence_time_start": "17:00",
  "occurrence_time_end": "19:00",
  "duration_minutes": 120
}
```

**Generated Occurrences**:
- Fri, Nov 29, 2025 5:00 PM - 7:00 PM (last Friday of November)
- Fri, Dec 27, 2025 5:00 PM - 7:00 PM (last Friday of December)
- Fri, Jan 31, 2026 5:00 PM - 7:00 PM (last Friday of January)

---

**End of Document**
