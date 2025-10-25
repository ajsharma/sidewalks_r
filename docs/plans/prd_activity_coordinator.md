# PRD: Activity Coordination & Scheduling

**Version:** 1.0
**Status:** Draft
**Last Updated:** 2025-10-09
**Owner:** Product Team

---

## 1. Overview

### Problem Statement
Users have busy calendars and many activities they'd like to do, but coordinating which activities to schedule and when is mentally taxing. Users need an intelligent system that:
- Understands their free time from Google Calendar
- Considers group interest levels from playlist watchers
- Factors in activity recency to avoid repetition
- Suggests optimal activities for open calendar slots

### Goals
Build an Activity Coordinator that automatically suggests activities to populate empty calendar days based on watcher interest, participation recency, and calendar availability.

### Success Metrics
- Number of activity suggestions generated per user per week
- User acceptance rate of suggested activities
- Reduction in manual activity scheduling time
- User satisfaction score with suggestions
- Percentage of "empty" calendar days successfully filled
- Diversity of activities scheduled (avoid repetition)

---

## 2. User Stories

### As a User
- I want to connect my Google Calendar so the system knows when I'm available
- I want the system to identify empty days in my calendar
- I want automated suggestions for which activities to schedule on those days
- I want suggestions to prioritize activities my friends are interested in
- I want to avoid being suggested the same activity too frequently
- I want to limit the number of suggested activities per day
- I want to review suggestions before they're added to my calendar
- I want to manually trigger the suggestion engine

### As a Playlist Watcher
- I want my interest ratings to influence which activities get suggested
- I want to see when other watchers last participated in activities
- I want to be notified when an activity I'm interested in is scheduled

---

## 3. Functional Requirements

### 3.1 Google Calendar Integration
- **FR-1.1:** Users can connect their Google account via OAuth 2.0
- **FR-1.2:** System stores access and refresh tokens securely
- **FR-1.3:** System can read user's primary Google Calendar
- **FR-1.4:** System can identify free/busy times on the calendar
- **FR-1.5:** Users can select which calendar(s) to sync
- **FR-1.6:** System automatically refreshes calendar data when needed
- **FR-1.7:** Users can disconnect their Google account

### 3.2 Empty Day Detection
- **FR-2.1:** System scans Google Calendar for days without events
- **FR-2.2:** System looks ahead up to 4 weekends into the future
- **FR-2.3:** System identifies "empty days" as days with < 2 hours of scheduled events (configurable)
- **FR-2.4:** System focuses on weekends by default (Friday-Sunday)
- **FR-2.5:** Users can configure which days are considered (include weekdays)
- **FR-2.6:** System respects user's timezone settings

### 3.3 Activity Suggestion Engine
- **FR-3.1:** Users can manually trigger the coordinator via "Suggest Activities" button
- **FR-3.2:** System suggests activities for each empty day identified
- **FR-3.3:** System suggests no more than 3 activities per day
- **FR-3.4:** System ranks suggestions based on a scoring algorithm
- **FR-3.5:** Suggestions are displayed to user for review before scheduling
- **FR-3.6:** Users can accept, reject, or modify suggestions
- **FR-3.7:** Accepted suggestions are added to Google Calendar
- **FR-3.8:** System tracks which activities were suggested and accepted/rejected

### 3.4 Ranking Algorithm (Activity Coordinator Module)
The system ranks activities based on:

**FR-4.1: Interest Score (Weight: 40%)**
- Aggregate interest level from all playlist watchers
- Higher average interest = higher ranking
- Considers number of watchers who have rated
- Formula: `(sum of interest ratings) / (number of ratings) * 0.4`

**FR-4.2: Recency Score (Weight: 40%)**
- Time since activity was last participated in
- Longer time since last participation = higher ranking
- Activities never done get highest recency score
- Formula: `(days since last participation / max lookback period) * 0.4`
- Max lookback: 180 days (configurable)

**FR-4.3: Activity Attributes (Weight: 20%)**
- `schedule_type`:
  - "deadline" activities get boosted if deadline is approaching
  - "scheduled" activities only suggested for their specific time slots
  - "flexible" activities can be suggested anytime
- `max_frequency_days`: Activities cannot be suggested within X days of last participation

**FR-4.4: Ranking Formula**
```
score = (interest_score * 0.4) + (recency_score * 0.4) + (attribute_score * 0.2)
```

### 3.5 Participation Tracking
- **FR-5.1:** System tracks when activities are completed/participated in
- **FR-5.2:** Users can manually mark activities as "completed" with a date
- **FR-5.3:** System can optionally auto-detect completion from Google Calendar (if event exists)
- **FR-5.4:** Participation history is visible on activity detail page
- **FR-5.5:** Watchers can see when other watchers last participated (optional)

---

## 4. Non-Functional Requirements

### Performance
- **NFR-1:** Calendar sync should complete in under 10 seconds
- **NFR-2:** Activity suggestion generation should complete in under 5 seconds
- **NFR-3:** System should cache calendar data for 1 hour to reduce API calls
- **NFR-4:** Suggestion engine should handle 1000+ activities per playlist

### Security & Privacy
- **NFR-5:** Google OAuth tokens stored encrypted in database
- **NFR-6:** System uses least-privilege Google API scopes
- **NFR-7:** Calendar data is never stored permanently (only cached temporarily)
- **NFR-8:** Users can revoke Google access at any time
- **NFR-9:** Comply with Google API Terms of Service

### Scalability
- **NFR-10:** Support multiple Google accounts per user
- **NFR-11:** Handle rate limits from Google Calendar API gracefully
- **NFR-12:** Background jobs for calendar syncing and suggestions

### Reliability
- **NFR-13:** Graceful degradation if Google API is unavailable
- **NFR-14:** Retry logic for failed API calls with exponential backoff
- **NFR-15:** Clear error messages if calendar sync fails

### User Experience
- **NFR-16:** Suggestion review interface should be scannable and actionable
- **NFR-17:** Users should be able to batch accept/reject suggestions
- **NFR-18:** Visual feedback during calendar sync and suggestion generation
- **NFR-19:** Educational tooltips explaining how suggestions are ranked

---

## 5. Data Model Requirements

### New Tables

#### `activity_participations`
- `id` (primary key)
- `activity_id` (foreign key → activities)
- `user_id` (foreign key → users)
- `playlist_id` (foreign key → playlists) # context
- `participated_at` (date/datetime)
- `source` (enum: manual, calendar, suggested)
- `notes` (text, optional)
- `created_at`
- `updated_at`
- **Constraints:**
  - Index on (activity_id, user_id, participated_at)
  - Index on participated_at for recency queries

#### `activity_suggestions`
- `id` (primary key)
- `user_id` (foreign key → users)
- `activity_id` (foreign key → activities)
- `playlist_id` (foreign key → playlists)
- `suggested_for_date` (date)
- `rank` (integer) # 1, 2, or 3 for the day
- `interest_score` (decimal)
- `recency_score` (decimal)
- `total_score` (decimal)
- `status` (enum: pending, accepted, rejected, scheduled)
- `accepted_at`
- `rejected_at`
- `rejection_reason` (text, optional)
- `created_at`
- `updated_at`
- **Constraints:**
  - Index on (user_id, suggested_for_date, status)
  - Composite index for analytics

#### `calendar_syncs`
- `id` (primary key)
- `google_account_id` (foreign key → google_accounts)
- `status` (enum: pending, in_progress, completed, failed)
- `events_count` (integer)
- `empty_days_found` (json) # array of dates
- `sync_range_start` (date)
- `sync_range_end` (date)
- `error_message` (text)
- `completed_at`
- `created_at`
- `updated_at`
- **Constraints:**
  - Index on (google_account_id, created_at)

### Table Modifications

#### `google_accounts` (existing - add columns)
- Add `selected_calendar_ids` (json array) - which calendars to sync
- Add `last_synced_at` (datetime)
- Add `sync_enabled` (boolean, default: true)

#### `activities` (existing - no changes needed)
- Already has: `schedule_type`, `deadline`, `max_frequency_days`

---

## 6. User Interface Requirements

### 6.1 Google Calendar Connection Page
- "Connect Google Calendar" OAuth button
- List of connected accounts with status
- Calendar selection (primary, secondary, etc.)
- Last sync timestamp
- "Sync Now" manual trigger
- "Disconnect" option

### 6.2 Activity Coordinator Dashboard
- **Trigger Section:**
  - "Suggest Activities" button
  - Configuration options:
    - Date range (default: 4 weekends)
    - Max suggestions per day (default: 3)
    - Include weekdays toggle
  - Last run timestamp

- **Calendar Preview:**
  - Weekly/monthly view showing empty days
  - Highlighted days with no events
  - Quick stats (X empty days found)

- **Suggestions Section:**
  - Grouped by date
  - Each suggestion shows:
    - Activity name
    - Playlist name
    - Interest score (visual)
    - Last participated date
    - Total rank score
    - Accept/Reject buttons
  - Batch actions (Accept All, Reject All)

### 6.3 Activity Detail Page (Enhanced)
- **Participation History:**
  - List of past participations with dates
  - "Mark as Completed" button
  - Who participated (if collaborative)

- **Scheduling Insights:**
  - "Suggested X times, accepted Y times"
  - Average interest level
  - Recency score visualization
  - Next eligible date (based on max_frequency_days)

### 6.4 Suggestions Review Modal
- Side-by-side view of suggested activities for a date
- Drag-to-reorder suggestions
- Add to calendar with time selection
- Add notes for the activity
- Quick interest rating update

---

## 7. Technical Architecture

### 7.1 Google Calendar Integration Flow
```
User clicks "Connect Google Calendar"
  → OAuth 2.0 redirect to Google
  → User grants permissions
  → Callback with authorization code
  → Exchange for access + refresh tokens
  → Store encrypted tokens in google_accounts table
  → Fetch calendar list
  → User selects calendars to sync
  → Initial sync triggered
```

### 7.2 Suggestion Generation Flow
```
User clicks "Suggest Activities"
  → Background job: CalendarSyncJob
    → Fetch events from Google Calendar (4 weeks)
    → Identify empty days
    → Store results in calendar_syncs
  → Background job: ActivitySuggestionJob
    → For each empty day:
      → Query eligible activities (not recently suggested/participated)
      → Calculate interest scores (from activity_interests)
      → Calculate recency scores (from activity_participations)
      → Apply schedule_type and max_frequency_days filters
      → Rank activities
      → Select top 3
      → Create activity_suggestions records
  → Return suggestions to user for review
```

### 7.3 Acceptance Flow
```
User clicks "Accept" on suggestion
  → Update suggestion status to accepted
  → Create activity_participation record
  → Create Google Calendar event (via API)
  → Send notification to playlist watchers (optional)
```

---

## 8. Business Rules

### BR-1: Suggestion Frequency
- Suggestions can be generated on-demand (manual trigger)
- Optional: Auto-generate weekly on Sundays
- Do not re-suggest the same activity for the same day if previously rejected

### BR-2: Activity Eligibility
- Activities must be in a playlist the user owns or watches
- Activities must not be archived
- Scheduled activities only suggested for their specific time window
- Activities with deadlines are boosted if deadline < 14 days away
- Activities respect `max_frequency_days` (cannot be suggested within X days of last participation)

### BR-3: Interest Calculation
- Interest score only considers active watchers (not archived)
- If no interest ratings exist, default interest score = 3.0
- Interest from playlist owner weighted higher (optional: 1.5x)

### BR-4: Participation Tracking
- Only the user can mark their own participations
- Participations from accepted suggestions are auto-created
- Participations can be backdated
- Participations cannot be in the future

### BR-5: Calendar Sync
- Sync only fetches future events (past events ignored)
- Sync respects Google Calendar API rate limits (handled by background job)
- Failed syncs retry up to 3 times with exponential backoff

### BR-6: Empty Day Definition
- Default: A day with < 2 hours of scheduled events
- User configurable in settings
- All-day events count as "busy" days
- Declined calendar events are ignored

---

## 9. Technical Considerations

### Technology Stack
- **Backend:** Rails 8, PostgreSQL
- **Background Jobs:** Solid Queue
- **Google API Client:** google-api-ruby-client gem
- **OAuth:** Omniauth-google-oauth2 gem (or Devise if already using)
- **Frontend:** Turbo Rails, Stimulus
- **Calendar UI:** Optional: FullCalendar.js or simple custom calendar

### External Dependencies
- **Google Calendar API v3**
  - Scopes needed: `calendar.readonly`, `calendar.events` (if writing events)
  - Rate limits: 1,000,000 queries/day (per project)
  - Cost: Free

### Performance Optimizations
- **Caching:**
  - Cache calendar data for 1 hour (Redis or Solid Cache)
  - Cache suggestion results per user until next generation

- **Database Indexes:**
  - `activity_participations.activity_id, participated_at`
  - `activity_suggestions.user_id, status, suggested_for_date`
  - `activity_interests.activity_id` for aggregation

- **Background Processing:**
  - All Google API calls in background jobs
  - Suggestion generation in background jobs (can take 5-10s)

### Error Handling
- **Token Expiry:** Automatically refresh using refresh_token
- **Token Revoked:** Notify user, mark account as disconnected
- **API Rate Limit:** Queue jobs for retry, show user "syncing in progress"
- **Network Errors:** Retry with exponential backoff (3 attempts)

### Security Considerations
- Encrypt `access_token` and `refresh_token` in database
- Use environment variables for Google OAuth client ID/secret
- Implement PKCE flow for OAuth (recommended)
- Validate all Google API responses before processing
- Scope down API permissions to minimum necessary

---

## 10. Algorithm Details

### Interest Score Calculation
```ruby
def calculate_interest_score(activity, playlist)
  ratings = activity.activity_interests
                    .where(playlist: playlist)
                    .where(archived_at: nil)

  return 3.0 if ratings.empty? # Default neutral score

  average = ratings.average(:interest_level).to_f
  confidence = [ratings.count / 5.0, 1.0].min # More ratings = more confidence

  (average * confidence) + (3.0 * (1 - confidence)) # Blend with default
end
```

### Recency Score Calculation
```ruby
def calculate_recency_score(activity, user)
  last_participation = activity.activity_participations
                               .where(user: user)
                               .order(participated_at: :desc)
                               .first

  return 5.0 if last_participation.nil? # Never done = max score

  days_since = (Date.today - last_participation.participated_at.to_date).to_i
  max_days = 180 # 6 months

  # Linear interpolation: 0 days = 0 score, 180+ days = 5 score
  [(days_since.to_f / max_days) * 5.0, 5.0].min
end
```

### Total Ranking Score
```ruby
def calculate_ranking_score(activity, user, playlist)
  interest = calculate_interest_score(activity, playlist)
  recency = calculate_recency_score(activity, user)

  # Attribute score based on schedule_type and deadline
  attribute_score = 3.0 # Base

  if activity.schedule_type == 'deadline' && activity.deadline.present?
    days_to_deadline = (activity.deadline.to_date - Date.today).to_i
    attribute_score = 5.0 if days_to_deadline < 7
    attribute_score = 4.0 if days_to_deadline.between?(7, 14)
  end

  (interest * 0.4) + (recency * 0.4) + (attribute_score * 0.2)
end
```

---

## 11. Out of Scope (Future Phases)

- Multi-user scheduling (finding times when all watchers are free)
- ML-based personalization of ranking weights
- Integration with other calendar services (Outlook, iCal)
- Smart conflict detection (e.g., location-based conflicts)
- Weather-based activity suggestions
- Budget tracking for activities with costs
- Automatic rescheduling if conflicts arise
- Group voting on suggested activities
- Mobile push notifications for suggestions
- Natural language interface ("Suggest something fun for this weekend")

---

## 12. Open Questions

1. **Calendar Write Permissions:** Should we write accepted suggestions directly to Google Calendar, or just suggest and let users add manually?
2. **Watcher Availability:** Should we check if other playlist watchers are free on suggested days?
3. **Time of Day:** Should suggestions include specific times, or just dates?
4. **Recurring Activities:** How should we handle activities that repeat weekly/monthly?
5. **Activity Duration:** Should we factor in activity duration when suggesting multiple activities per day?
6. **Participation Proof:** Should we require proof of participation (photo, check-in)?
7. **Collaborative Scheduling:** Should the coordinator try to find dates when multiple watchers are free?
8. **Auto-Accept:** Should users be able to set criteria for auto-accepting suggestions?

---

## 13. Success Criteria & Launch Readiness

### Minimum Viable Product (MVP)
- ✅ Users can connect Google Calendar via OAuth
- ✅ System can identify empty days in calendar (4 weeks ahead)
- ✅ Users can manually trigger activity suggestions
- ✅ System generates ranked suggestions based on interest + recency
- ✅ Suggestions respect schedule_type and max_frequency_days
- ✅ Users can accept/reject suggestions
- ✅ Accepted suggestions create participation records
- ✅ Maximum 3 suggestions per day enforced

### Phase 2 Enhancements
- Write accepted suggestions to Google Calendar as events
- Automatic weekly suggestion generation
- Notification to watchers when activities are scheduled
- Participation history analytics
- Customizable ranking algorithm weights
- Multi-calendar support

### Testing Requirements
- Unit tests for ranking algorithm
- Integration tests for Google Calendar API
- Mock OAuth flow in tests
- System tests for suggestion acceptance flow
- Performance tests with 1000+ activities
- Edge case testing (no empty days, no eligible activities)
- Token refresh testing

---

## 14. Timeline & Milestones

| Milestone | Description | Target |
|-----------|-------------|--------|
| Google OAuth Setup | Connect/disconnect Google accounts | Week 1 |
| Calendar Sync | Fetch and parse calendar events | Week 2 |
| Empty Day Detection | Identify available calendar slots | Week 2 |
| Participation Tracking | Model and UI for participation history | Week 3 |
| Ranking Algorithm | Implement interest + recency scoring | Week 4 |
| Suggestion Engine | Generate ranked suggestions | Week 5 |
| Review UI | Interface to accept/reject suggestions | Week 6 |
| Background Jobs | Move to async processing | Week 7 |
| Testing & Polish | Full test coverage, edge cases | Week 8 |
| Beta Launch | Limited user testing | Week 9 |

---

## 15. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Google API rate limits | High | Medium | Implement caching, background jobs, rate limiting |
| Poor suggestion quality | High | Medium | A/B test ranking weights, gather user feedback |
| Calendar sync failures | Medium | Medium | Robust error handling, retry logic, user notifications |
| User privacy concerns | High | Low | Clear privacy policy, minimal data storage, easy disconnect |
| Complex scheduling logic | Medium | High | Start simple, iterate based on usage patterns |
| Low user engagement | High | Medium | Onboarding tutorial, clear value proposition, email reminders |

---

## Appendix: Google Calendar API Reference
- **Events List:** `GET /calendars/{calendarId}/events`
- **Events Insert:** `POST /calendars/{calendarId}/events`
- **FreeBusy Query:** `POST /freeBusy`

## Appendix: Wireframes
*[To be added: Figma links for coordinator dashboard, suggestion review UI]*

## Appendix: Technical Architecture Diagram
*[To be added: Flow diagrams for sync and suggestion processes]*
