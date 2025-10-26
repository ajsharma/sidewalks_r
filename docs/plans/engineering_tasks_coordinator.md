# Engineering Tasks: Activity Coordinator & Scheduling

**PRD:** Activity Coordination & Scheduling
**Status:** Ready for Implementation
**Estimated Duration:** 7-9 weeks

---

## Phase 1: Google Calendar OAuth Setup (Week 1)

### 1.1 Google Cloud Configuration

- [ ] **Set up Google Cloud Project**
  - Create new project in Google Cloud Console (or use existing)
  - Enable Google Calendar API
  - Create OAuth 2.0 credentials (Web application)
  - Add authorized redirect URIs:
    - `http://localhost:3000/auth/google/callback` (development)
    - `https://yourdomain.com/auth/google/callback` (production)
  - Copy Client ID and Client Secret

- [ ] **Configure environment variables**
  - Add `GOOGLE_CLIENT_ID` to credentials/ENV
  - Add `GOOGLE_CLIENT_SECRET` to credentials/ENV
  - Update `.env.example` with new vars

### 1.2 Gem Installation

- [ ] **Add gems to Gemfile**
  ```ruby
  gem 'omniauth-google-oauth2'
  gem 'omniauth-rails_csrf_protection'
  gem 'google-apis-calendar_v3'
  ```

- [ ] **Run bundle install**

- [ ] **Create OmniAuth initializer**
  - `config/initializers/omniauth.rb`
  - Configure Google OAuth provider
  - Set scopes: `calendar.readonly`, `calendar.events` (optional for writing)
  - Enable PKCE flow for security

### 1.3 Database Migrations

- [ ] **Migration: Update `google_accounts` table**
  - Add `selected_calendar_ids` (jsonb, default: [])
  - Add `last_synced_at` (datetime)
  - Add `sync_enabled` (boolean, default: true)
  - Add `sync_status` (enum: idle, syncing, failed)
  - Add `sync_error_message` (text)

- [ ] **Migration: Create `calendar_syncs` table**
  - `google_account_id` (foreign key, indexed)
  - `status` (enum: pending, in_progress, completed, failed)
  - `events_count` (integer)
  - `empty_days_found` (jsonb) - array of date strings
  - `sync_range_start` (date)
  - `sync_range_end` (date)
  - `error_message` (text)
  - `completed_at` (datetime)
  - `created_at`, `updated_at`
  - Composite index on (google_account_id, created_at)

- [ ] **Migration: Create `activity_participations` table**
  - `activity_id` (foreign key, indexed)
  - `user_id` (foreign key, indexed)
  - `playlist_id` (foreign key, indexed, nullable)
  - `participated_at` (date, not null)
  - `source` (enum: manual, calendar, suggested)
  - `notes` (text)
  - `google_calendar_event_id` (string, nullable)
  - `created_at`, `updated_at`, `archived_at`
  - Composite index on (activity_id, user_id, participated_at)
  - Index on participated_at

- [ ] **Migration: Create `activity_suggestions` table**
  - `user_id` (foreign key, indexed)
  - `activity_id` (foreign key, indexed)
  - `playlist_id` (foreign key, indexed)
  - `suggested_for_date` (date, not null)
  - `rank` (integer) - 1, 2, or 3
  - `interest_score` (decimal)
  - `recency_score` (decimal)
  - `attribute_score` (decimal)
  - `total_score` (decimal)
  - `status` (enum: pending, accepted, rejected, scheduled)
  - `acceptance_notes` (text)
  - `accepted_at`, `rejected_at` (datetime)
  - `created_at`, `updated_at`
  - Composite index on (user_id, suggested_for_date, status)
  - Index on (activity_id, status)

### 1.4 Models

- [ ] **Update `GoogleAccount` model**
  - Validations: presence of email, google_id, user_id
  - Add attributes: selected_calendar_ids, last_synced_at, sync_enabled
  - Encrypt access_token and refresh_token with Rails credentials
  - Add associations:
    - `has_many :calendar_syncs`
  - Add methods:
    - `token_expired?` - check if access_token expired
    - `refresh_token!` - refresh access token using refresh_token
    - `disconnect!` - revoke tokens and archive
    - `calendar_client` - returns authenticated Google::Apis::CalendarV3::CalendarService

- [ ] **Create `CalendarSync` model**
  - Belongs to google_account
  - Validations: presence of google_account_id, sync_range_start, sync_range_end
  - Scopes: recent, completed, failed
  - Methods:
    - `mark_completed!(events:, empty_days:)`
    - `mark_failed!(error:)`

- [ ] **Create `ActivityParticipation` model**
  - Belongs to activity
  - Belongs to user
  - Belongs to playlist (optional)
  - Validations: presence of activity_id, user_id, participated_at
  - Validations: participated_at cannot be in future
  - Scopes: recent, for_activity, manual, from_calendar
  - Methods:
    - `self.last_participation_for(activity, user)` - returns most recent

- [ ] **Create `ActivitySuggestion` model**
  - Belongs to user
  - Belongs to activity
  - Belongs to playlist
  - Validations: presence of user_id, activity_id, suggested_for_date
  - Validations: rank between 1-3
  - Validations: status in allowed values
  - Scopes: pending, accepted, rejected, for_date
  - Methods:
    - `accept!(notes: nil)`
    - `reject!(reason: nil)`
    - `calculate_scores!` - recalculates all scores

- [ ] **Update `User` model**
  - Add association: `has_many :activity_participations`
  - Add association: `has_many :activity_suggestions`
  - Add method: `primary_google_account` - returns first active google account
  - Add method: `has_google_calendar?` - check if connected

- [ ] **Update `Activity` model**
  - Add association: `has_many :activity_participations`
  - Add association: `has_many :activity_suggestions`
  - Add method: `last_participated_by(user)` - returns ActivityParticipation or nil
  - Add method: `eligible_for_suggestion?(user, date)` - checks eligibility

### 1.5 Tests (Models)

- [ ] **Test `GoogleAccount` model updates**
  - Token expiration check works
  - Token refresh updates access_token
  - disconnect! revokes and archives
  - calendar_client returns authenticated client

- [ ] **Test `CalendarSync` model**
  - Valid creation
  - mark_completed! sets correct fields
  - mark_failed! stores error message

- [ ] **Test `ActivityParticipation` model**
  - Valid creation with past date
  - Invalid with future date
  - last_participation_for returns most recent

- [ ] **Test `ActivitySuggestion` model**
  - Valid creation with required fields
  - Rank must be 1-3
  - accept! changes status and creates participation
  - reject! changes status

---

## Phase 2: OAuth Flow & Connection UI (Week 1-2)

### 2.1 Routes

- [ ] **Add OAuth routes**
  ```ruby
  get '/auth/google_oauth2/callback', to: 'google_accounts#callback'
  get '/auth/failure', to: 'google_accounts#failure'

  resources :google_accounts, only: [:index, :create, :destroy] do
    member do
      post :sync
      patch :update_settings
    end
  end
  ```

### 2.2 Controllers

- [ ] **Update `GoogleAccountsController`**
  - `index` - GET /google_accounts - list connected accounts
  - `create` - redirects to Google OAuth
  - `callback` - handles OAuth callback, creates GoogleAccount
  - `destroy` - disconnects Google account
  - `sync` - POST - manually triggers calendar sync
  - `update_settings` - PATCH - update selected_calendar_ids, sync_enabled

### 2.3 Services

- [ ] **Create `GoogleAuth::TokenExchanger`**
  - Takes authorization code
  - Exchanges for access_token and refresh_token
  - Returns hash with tokens and expiry

- [ ] **Create `GoogleAuth::TokenRefresher`**
  - Takes GoogleAccount
  - Uses refresh_token to get new access_token
  - Updates GoogleAccount record
  - Handles errors (token revoked)

- [ ] **Create `GoogleCalendar::Client`**
  - Initializes Google::Apis::CalendarV3::CalendarService
  - Handles authentication
  - Wrapper methods:
    - `list_calendars` - returns user's calendars
    - `list_events(calendar_id, time_min, time_max)` - returns events
    - `create_event(calendar_id, event_data)` - creates event
    - `freebusy_query(calendar_ids, time_min, time_max)` - returns free/busy

### 2.4 Views

- [ ] **Create `google_accounts/index.html.erb`**
  - Title: "Google Calendar Integration"
  - "Connect Google Calendar" button (if none connected)
  - List of connected accounts:
    - Email
    - Last synced timestamp
    - Sync status (idle, syncing, failed)
    - "Sync Now" button
    - "Settings" link
    - "Disconnect" button
  - Error messages if sync failed

- [ ] **Create `google_accounts/_settings_modal.html.erb`**
  - Checkbox list of user's calendars
  - Select which calendars to sync
  - Toggle for "Enable automatic sync"
  - Save button

- [ ] **Create `google_accounts/failure.html.erb`**
  - Error page if OAuth fails
  - Message explaining what went wrong
  - Link to try again

### 2.5 Tests

- [ ] **Controller tests: `GoogleAccountsController`**
  - GET index shows connected accounts
  - POST create redirects to Google OAuth
  - callback with valid code creates GoogleAccount
  - callback with invalid code shows error
  - DELETE destroy disconnects account
  - POST sync enqueues CalendarSyncJob

- [ ] **Service tests: `GoogleAuth::TokenExchanger`**
  - Exchanges valid code for tokens
  - Handles invalid code error

- [ ] **Service tests: `GoogleAuth::TokenRefresher`**
  - Refreshes token successfully
  - Handles revoked token error

- [ ] **System test: OAuth flow**
  - User clicks "Connect Google Calendar"
  - User is redirected to Google (mock in test)
  - User grants permission
  - User is redirected back
  - GoogleAccount is created
  - User sees connected account

---

## Phase 3: Calendar Sync & Empty Day Detection (Week 2-3)

### 3.1 Background Jobs

- [ ] **Create `CalendarSyncJob`**
  - Takes google_account_id, date_range_start, date_range_end
  - Creates CalendarSync record (status: in_progress)
  - Fetches events from Google Calendar
  - Analyzes events to find empty days
  - Stores results in CalendarSync (completed or failed)
  - Enqueues ActivitySuggestionJob if successful

### 3.2 Services

- [ ] **Create `GoogleCalendar::EventFetcher`**
  - Takes GoogleAccount and date range
  - Fetches all events from selected calendars
  - Returns normalized event data:
    - Event ID
    - Calendar ID
    - Summary
    - Start time
    - End time
    - All-day flag
    - Status (confirmed, cancelled)
  - Handles pagination
  - Handles API rate limits with retry

- [ ] **Create `Calendar::EmptyDayDetector`**
  - Takes array of events and date range
  - Groups events by day
  - Calculates busy hours per day
  - Identifies "empty" days based on criteria:
    - < 2 hours of events (configurable)
    - Excludes all-day events as "busy"
    - Excludes cancelled events
  - Returns array of empty dates

- [ ] **Create `Calendar::WeekendFinder`**
  - Takes date range
  - Returns array of weekend dates (Friday-Sunday)
  - Respects user's timezone

### 3.3 Configuration

- [ ] **Add configuration options**
  - `config/initializers/calendar_sync.rb`
  - Default sync range: 4 weekends (28 days)
  - Empty day threshold: 2 hours
  - Max suggestions per day: 3
  - Sync frequency: weekly

- [ ] **Add user settings**
  - Add columns to `users` table (or `user_settings`):
    - `calendar_sync_range_weeks` (default: 4)
    - `empty_day_threshold_hours` (default: 2)
    - `include_weekdays_in_sync` (default: false)
    - `max_suggestions_per_day` (default: 3)

### 3.4 Tests

- [ ] **Job tests: `CalendarSyncJob`**
  - Creates CalendarSync record
  - Fetches events successfully
  - Finds empty days
  - Marks sync as completed
  - Handles Google API errors

- [ ] **Service tests: `GoogleCalendar::EventFetcher`**
  - Fetches events from Google Calendar (mocked)
  - Handles pagination
  - Handles API rate limit (retry)
  - Normalizes event data

- [ ] **Service tests: `Calendar::EmptyDayDetector`**
  - Identifies days with < 2 hours as empty
  - Excludes all-day events
  - Excludes cancelled events
  - Handles timezone correctly

- [ ] **Integration test: Full sync flow**
  - CalendarSyncJob enqueued
  - Events fetched
  - Empty days identified
  - Results stored in CalendarSync

---

## Phase 4: Activity Eligibility & Ranking (Week 3-4)

### 4.1 Services

- [ ] **Create `ActivityCoordinator::EligibilityChecker`**
  - Takes activity, user, date
  - Returns true/false if activity is eligible for suggestion
  - Checks:
    - Activity not archived
    - Activity in user's playlists (owned or watching)
    - Respects `max_frequency_days` (not suggested within X days of last participation)
    - Respects `schedule_type`:
      - "scheduled" → only suggest for exact start_time date
      - "deadline" → only suggest before deadline
      - "flexible" → always eligible
    - Not already suggested for this date (pending/accepted)

- [ ] **Create `ActivityCoordinator::InterestScorer`**
  - Takes activity, playlist
  - Calculates interest score (0-5)
  - Logic:
    - If no ratings exist: return 3.0 (neutral)
    - Average of all active watcher ratings
    - Apply confidence factor based on number of ratings
    - Formula: `(average * confidence) + (3.0 * (1 - confidence))`
    - Confidence: `min(rating_count / 5.0, 1.0)`

- [ ] **Create `ActivityCoordinator::RecencyScorer`**
  - Takes activity, user
  - Calculates recency score (0-5)
  - Logic:
    - If never participated: return 5.0 (max score)
    - Calculate days since last participation
    - Linear interpolation: 0 days = 0, 180+ days = 5.0
    - Formula: `min((days_since / 180.0) * 5.0, 5.0)`

- [ ] **Create `ActivityCoordinator::AttributeScorer`**
  - Takes activity, date
  - Calculates attribute score (0-5)
  - Logic:
    - Base score: 3.0
    - If `schedule_type == 'deadline'`:
      - Days to deadline < 7: score = 5.0
      - Days to deadline 7-14: score = 4.0
      - Days to deadline > 14: score = 3.0
    - If `schedule_type == 'scheduled'`:
      - Exact match date: score = 5.0
      - Otherwise: ineligible
    - If `schedule_type == 'flexible'`: score = 3.0

- [ ] **Create `ActivityCoordinator::RankingEngine`**
  - Takes array of eligible activities, user, date, playlist
  - For each activity, calculates:
    - `interest_score` (40% weight)
    - `recency_score` (40% weight)
    - `attribute_score` (20% weight)
    - `total_score = (interest * 0.4) + (recency * 0.4) + (attribute * 0.2)`
  - Sorts by total_score descending
  - Returns top N activities (default 3)

### 4.2 Tests

- [ ] **Service tests: `ActivityCoordinator::EligibilityChecker`**
  - Archived activity is not eligible
  - Activity with max_frequency_days is not eligible if participated recently
  - Scheduled activity is only eligible on exact date
  - Activity past deadline is not eligible
  - Already suggested activity is not eligible

- [ ] **Service tests: `ActivityCoordinator::InterestScorer`**
  - No ratings returns 3.0
  - Single rating returns that rating
  - Multiple ratings return weighted average
  - Confidence factor applies correctly

- [ ] **Service tests: `ActivityCoordinator::RecencyScorer`**
  - Never participated returns 5.0
  - Participated today returns 0.0
  - Participated 180+ days ago returns 5.0
  - Linear interpolation works

- [ ] **Service tests: `ActivityCoordinator::AttributeScorer`**
  - Deadline activities get boosted near deadline
  - Scheduled activities get 5.0 on exact date
  - Flexible activities get 3.0

- [ ] **Service tests: `ActivityCoordinator::RankingEngine`**
  - Ranks activities by total score
  - Returns top N activities
  - Handles empty array

- [ ] **Integration test: End-to-end ranking**
  - Create 10 activities with various attributes
  - Create interest ratings
  - Create participations
  - Run ranking engine
  - Verify top 3 are correct based on scores

---

## Phase 5: Suggestion Generation (Week 4-5)

### 5.1 Background Jobs

- [ ] **Create `ActivitySuggestionJob`**
  - Takes user_id, empty_days (array of dates)
  - For each empty day:
    - Fetch user's playlists (owned + watching)
    - Fetch all activities in those playlists
    - Filter for eligible activities (EligibilityChecker)
    - Rank activities (RankingEngine)
    - Create ActivitySuggestion records (top 3, with rank 1-3)
  - Stores scores in ActivitySuggestion (interest, recency, attribute, total)

### 5.2 Services

- [ ] **Create `ActivityCoordinator::SuggestionGenerator`**
  - Orchestrates the suggestion generation process
  - Takes user, date_range
  - Calls CalendarSyncJob to get empty days
  - Calls ActivitySuggestionJob for each day
  - Returns summary (X suggestions created for Y days)

### 5.3 Tests

- [ ] **Job tests: `ActivitySuggestionJob`**
  - Creates suggestions for each empty day
  - Limits to 3 suggestions per day
  - Stores scores correctly
  - Handles no eligible activities gracefully

- [ ] **Service tests: `ActivityCoordinator::SuggestionGenerator`**
  - Triggers calendar sync
  - Generates suggestions for empty days
  - Returns summary

---

## Phase 6: Suggestion Review UI (Week 5-6)

### 6.1 Controllers

- [ ] **Create `ActivityCoordinator::DashboardController`**
  - `show` - GET /activity_coordinator - main dashboard
  - Shows:
    - Connected Google accounts
    - Last sync info
    - "Generate Suggestions" button
    - Link to suggestions review page

- [ ] **Create `ActivitySuggestionsController`**
  - `index` - GET /activity_suggestions - list all suggestions
  - `show` - GET /activity_suggestions/:id - detail view
  - `accept` - POST /activity_suggestions/:id/accept
  - `reject` - POST /activity_suggestions/:id/reject
  - `batch_accept` - POST /activity_suggestions/batch_accept (array of IDs)
  - `batch_reject` - POST /activity_suggestions/batch_reject (array of IDs)

- [ ] **Create `ActivityParticipationsController`**
  - `create` - POST /activity_participations - manually mark as completed
  - `update` - PATCH /activity_participations/:id
  - `destroy` - DELETE /activity_participations/:id

### 6.2 Views

- [ ] **Create `activity_coordinator/dashboard/show.html.erb`**
  - Section 1: Google Calendar Connection
    - Status (connected/not connected)
    - Last sync timestamp
    - "Sync Now" button
    - Link to settings
  - Section 2: Configuration
    - Date range slider (1-8 weeks)
    - Max suggestions per day (1-5)
    - Include weekdays checkbox
  - Section 3: Generate
    - Large "Generate Activity Suggestions" button
    - Shows loading state when clicked
  - Section 4: Recent Suggestions
    - Link to suggestions review page
    - Count of pending suggestions

- [ ] **Create `activity_suggestions/index.html.erb`**
  - Title: "Activity Suggestions"
  - Filters: All / Pending / Accepted / Rejected
  - Group by date
  - For each date:
    - Show as expandable accordion or cards
    - Show empty day visualization (mini calendar)
  - For each suggestion:
    - Activity name (link to activity detail)
    - Playlist name
    - Rank badge (1st, 2nd, 3rd)
    - Score breakdown:
      - Interest score (visual bar)
      - Recency score (visual bar)
      - Total score (large number)
    - Last participated date
    - Accept / Reject buttons
  - Batch actions: "Accept All" / "Reject All"

- [ ] **Create `activity_suggestions/_suggestion_card.html.erb` partial**
  - Reusable card for displaying suggestion
  - Shows all relevant info
  - Action buttons

- [ ] **Create `activity_suggestions/show.html.erb`**
  - Detail view for single suggestion
  - Larger view of all info
  - Activity description
  - List of playlist watchers and their interest
  - "Add to Calendar" form:
    - Date (pre-filled)
    - Time picker
    - Notes field
    - "Accept & Add to Calendar" button

- [ ] **Create `activities/_participation_history.html.erb` partial**
  - Shows on activity detail page
  - Table of past participations:
    - Date
    - Source (manual, calendar, suggested)
    - Notes
    - Delete button (if manual)
  - "Mark as Completed" button

- [ ] **Create `activity_participations/_form.html.erb` partial**
  - Date picker
  - Notes field
  - Source (manual)
  - Submit button

### 6.3 Stimulus Controllers

- [ ] **Create `suggestion_generator_controller.js`**
  - Handles "Generate Suggestions" button click
  - Shows loading spinner
  - Polls for job completion
  - Redirects to suggestions page when done
  - Shows error if job fails

- [ ] **Create `suggestion_card_controller.js`**
  - Handles Accept/Reject button clicks
  - Submits AJAX request
  - Updates UI optimistically
  - Removes card on accept/reject
  - Shows success message

- [ ] **Create `batch_actions_controller.js`**
  - Handles "Accept All" / "Reject All"
  - Checkbox selection
  - Bulk POST request
  - Updates UI for all cards

- [ ] **Create `calendar_preview_controller.js`**
  - Displays mini calendar showing empty days
  - Highlights suggested dates
  - Click to filter suggestions by date

### 6.4 Routes

- [ ] **Add coordinator routes**
  ```ruby
  namespace :activity_coordinator do
    resource :dashboard, only: [:show]
  end

  resources :activity_suggestions, only: [:index, :show] do
    member do
      post :accept
      post :reject
    end
    collection do
      post :batch_accept
      post :batch_reject
    end
  end

  resources :activity_participations, only: [:create, :update, :destroy]
  ```

### 6.5 Tests

- [ ] **Controller tests: `ActivityCoordinator::DashboardController`**
  - GET show displays dashboard
  - Shows connection status
  - Shows generate button

- [ ] **Controller tests: `ActivitySuggestionsController`**
  - GET index lists suggestions grouped by date
  - POST accept creates participation and updates suggestion
  - POST reject updates suggestion status
  - POST batch_accept accepts multiple suggestions
  - Authorization: user can only accept their own suggestions

- [ ] **System test: Suggestion review flow**
  - User navigates to suggestions page
  - User sees suggestions grouped by date
  - User clicks "Accept" on suggestion
  - Suggestion is accepted and removed from list
  - User sees success message

- [ ] **System test: Generate suggestions flow**
  - User clicks "Generate Suggestions"
  - Loading spinner appears
  - Suggestions are generated (background job)
  - User is redirected to suggestions page
  - User sees generated suggestions

---

## Phase 7: Google Calendar Event Creation (Week 6-7)

### 7.1 Services

- [ ] **Create `GoogleCalendar::EventCreator`**
  - Takes ActivitySuggestion, time, notes
  - Creates event data hash:
    - Summary: activity name
    - Description: activity description + notes
    - Start/end time
    - Attendees (optional: other playlist watchers)
  - Calls Google Calendar API to create event
  - Returns event ID
  - Handles errors (rate limit, API failure)

- [ ] **Create `GoogleCalendar::EventUpdater`**
  - Updates existing calendar event
  - Takes event_id and new data

- [ ] **Create `GoogleCalendar::EventDeleter`**
  - Deletes calendar event
  - Takes event_id

### 7.2 Background Jobs

- [ ] **Create `CreateCalendarEventJob`**
  - Takes activity_suggestion_id, time, notes
  - Creates calendar event via EventCreator
  - Updates ActivityParticipation with google_calendar_event_id
  - Handles errors and retries

### 7.3 Controller Updates

- [ ] **Update `ActivitySuggestionsController#accept`**
  - Accept suggestion
  - Optionally create Google Calendar event if params[:add_to_calendar]
  - Enqueue CreateCalendarEventJob

### 7.4 View Updates

- [ ] **Update suggestion accept form**
  - Add checkbox: "Add to Google Calendar"
  - Add time picker (default: 10:00 AM)
  - Add notes field

### 7.5 Tests

- [ ] **Service tests: `GoogleCalendar::EventCreator`**
  - Creates event successfully (mocked API)
  - Handles API errors
  - Returns event ID

- [ ] **Job tests: `CreateCalendarEventJob`**
  - Creates calendar event
  - Updates participation with event_id
  - Retries on failure

- [ ] **System test: Add to calendar**
  - User accepts suggestion with "Add to calendar" checked
  - Event is created in Google Calendar (mocked)
  - Participation has event_id

---

## Phase 8: Participation Tracking & Analytics (Week 7-8)

### 8.1 Views

- [ ] **Create `activity_participations/index.html.erb`**
  - User's participation history across all activities
  - Filters: All / This month / Last 3 months
  - Group by month
  - Each participation shows:
    - Activity name
    - Date
    - Source (manual, calendar, suggested)
    - Notes
  - Analytics:
    - Total activities completed
    - Most frequent activity
    - Average days between activities

- [ ] **Update `activities/show.html.erb`**
  - Add "Participation History" section
  - Show timeline of past participations
  - Show "Days since last participated"
  - Show "Average frequency" if multiple participations

- [ ] **Create analytics dashboard**
  - `activity_coordinator/analytics/show.html.erb`
  - Charts:
    - Activities completed over time (line chart)
    - Activity distribution (pie chart)
    - Suggestion acceptance rate
    - Most popular activities

### 8.2 Services

- [ ] **Create `ActivityCoordinator::Analytics`**
  - Methods:
    - `total_participations(user)`
    - `participations_by_month(user)`
    - `most_frequent_activity(user)`
    - `suggestion_acceptance_rate(user)`
    - `average_days_between_activities(user)`

### 8.3 Tests

- [ ] **Service tests: `ActivityCoordinator::Analytics`**
  - Calculates total participations
  - Finds most frequent activity
  - Calculates acceptance rate

---

## Phase 9: Notifications & Email Digests (Week 8)

### 9.1 Mailers

- [ ] **Create `ActivityCoordinatorMailer`**
  - `suggestions_ready(user, suggestions_count)`
    - Subject: "Your Activity Suggestions are Ready!"
    - Body: "We've found X activities for Y empty days"
    - Link to suggestions page
  - `weekly_digest(user)`
    - Subject: "Your Weekly Activity Summary"
    - Body: Participations this week, upcoming suggestions
  - `sync_failed(google_account)`
    - Subject: "Google Calendar Sync Failed"
    - Body: Error details, link to reconnect

### 9.2 Background Jobs

- [ ] **Create `SendSuggestionReadyEmailJob`**
  - Enqueued after ActivitySuggestionJob completes
  - Sends email notification

- [ ] **Create `WeeklyDigestJob`**
  - Scheduled to run every Sunday
  - Sends digest to all users with active Google accounts
  - Skips users who opted out

### 9.3 Tests

- [ ] **Mailer tests**
  - Suggestions ready email sends correctly
  - Weekly digest email sends correctly
  - Sync failed email sends correctly

---

## Phase 10: Configuration & Settings (Week 8-9)

### 10.1 User Settings

- [ ] **Migration: Add settings to users table**
  - `coordinator_email_notifications` (boolean, default: true)
  - `coordinator_weekly_digest` (boolean, default: true)
  - `coordinator_sync_range_weeks` (integer, default: 4)
  - `coordinator_empty_day_threshold_hours` (integer, default: 2)
  - `coordinator_include_weekdays` (boolean, default: false)
  - `coordinator_max_suggestions_per_day` (integer, default: 3)

- [ ] **Views: Settings page**
  - Add "Activity Coordinator" section to user settings
  - Form for all coordinator settings
  - Save button

- [ ] **Controller: Update `SettingsController`**
  - Add coordinator settings to permitted params
  - Update user settings

### 10.2 Tests

- [ ] **System test: Update coordinator settings**
  - User navigates to settings
  - User changes sync range to 6 weeks
  - User saves settings
  - Settings are persisted

---

## Phase 11: Performance Optimization (Week 9)

### 11.1 Caching

- [ ] **Add caching to expensive operations**
  - Cache calendar events for 1 hour
  - Cache empty days result for 1 hour
  - Cache suggestion rankings (invalidate on participation)

- [ ] **Implement cache strategies**
  - Use Solid Cache or Redis
  - Add cache keys to models
  - Add cache invalidation callbacks

### 11.2 Database Optimization

- [ ] **Add missing indexes**
  - Review query performance with `bullet` gem
  - Add indexes where N+1 detected
  - Composite indexes for common queries

- [ ] **Optimize queries**
  - Eager load associations in controllers
  - Use `includes`, `joins` where appropriate
  - Batch load suggestions on index page

### 11.3 Background Job Optimization

- [ ] **Add job priorities**
  - High priority: Token refresh
  - Medium priority: Calendar sync
  - Low priority: Suggestion generation

- [ ] **Add job concurrency limits**
  - Limit concurrent calendar syncs per user
  - Prevent duplicate jobs

### 11.4 Tests

- [ ] **Performance tests**
  - Test with 1000+ activities
  - Test with 50+ playlists
  - Test with 100+ suggestions
  - Ensure queries stay under 100ms

---

## Phase 12: Testing & Quality Assurance (Week 9)

### 12.1 Test Coverage

- [ ] **Ensure 90%+ test coverage**
  - Run SimpleCov
  - Add missing unit tests
  - Add missing integration tests

- [ ] **System tests for all flows**
  - OAuth connection flow
  - Calendar sync flow
  - Suggestion generation flow
  - Suggestion acceptance flow
  - Participation tracking flow
  - Settings update flow

### 12.2 Error Handling

- [ ] **Graceful error handling**
  - Google API rate limit
  - Token expired/revoked
  - Network timeout
  - Invalid calendar data

- [ ] **User-friendly error messages**
  - Clear messaging for all error states
  - Actionable next steps

### 12.3 Security Audit

- [ ] **Security review**
  - Ensure tokens are encrypted
  - Check authorization on all endpoints
  - Validate external API responses
  - Prevent injection attacks on calendar data

- [ ] **Run Brakeman**
  - Fix all security warnings

### 12.4 Accessibility

- [ ] **WCAG compliance**
  - Test with screen reader
  - Keyboard navigation
  - Color contrast
  - ARIA labels

---

## Phase 13: Documentation & Launch (Week 9)

### 13.1 User Documentation

- [ ] **Create user guide**
  - How to connect Google Calendar
  - How to generate suggestions
  - How to accept/reject suggestions
  - How to track participations
  - FAQ

- [ ] **Create onboarding flow**
  - Welcome modal
  - Step-by-step tutorial
  - Sample data

### 13.2 Developer Documentation

- [ ] **Update README**
  - Document Google OAuth setup
  - Document background job queues
  - Document ranking algorithm

- [ ] **Add code documentation**
  - YARD docs for complex services
  - Inline comments for business logic

### 13.3 Deployment

- [ ] **Pre-deployment checklist**
  - Run migrations on staging
  - Test background jobs on staging
  - Test email delivery
  - Update production credentials

- [ ] **Deploy to production**
  - Run migrations
  - Monitor error logs
  - Monitor background job queue
  - Monitor Google API usage

- [ ] **Post-deployment monitoring**
  - Track suggestion generation success rate
  - Track acceptance rate
  - Track API errors
  - Track job failures

---

## Dependencies & Prerequisites

### External Dependencies
- Google Cloud Project (with Calendar API enabled)
- Google OAuth credentials
- Email delivery setup (SMTP or SendGrid)

### Internal Dependencies
- User model (existing)
- Activity model (existing)
- Playlist model (existing)
- ActivityInterest model (from Social PRD)
- PlaylistWatcher model (from Social PRD)

### Gems Required
- `omniauth-google-oauth2`
- `google-apis-calendar_v3`
- `omniauth-rails_csrf_protection`

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Google API rate limits | High | Implement caching, rate limiting, exponential backoff |
| Complex ranking algorithm | Medium | Start simple, iterate based on user feedback |
| Token refresh failures | High | Robust error handling, user notifications |
| Background job failures | Medium | Retry logic, monitoring, alerts |
| Poor suggestion quality | High | A/B test ranking weights, gather feedback |
| Calendar sync latency | Low | Set user expectations, show progress |

---

## Metrics & Monitoring

### Key Metrics
- Calendar connections per user
- Sync success rate
- Suggestions generated per user
- Acceptance rate
- Participations tracked
- Average ranking scores

### Alerts
- Google API error rate > 5%
- Background job failure rate > 10%
- Token refresh failure rate > 2%
- Calendar sync latency > 30 seconds

---

## Post-Launch Iteration

### Phase 2 Features
- Multi-user scheduling (find times all watchers free)
- ML-based personalization of ranking weights
- Integration with other calendar services
- Smart conflict detection
- Weather-based suggestions
- Budget tracking
- Natural language interface
