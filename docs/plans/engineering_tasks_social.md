# Engineering Tasks: Social & Collaboration Features

**PRD:** Social & Collaboration Features
**Status:** Ready for Implementation
**Estimated Duration:** 4-5 weeks

---

## Phase 1: Foundation & Data Models (Week 1)

### 1.1 Database Migrations

- [ ] **Migration: Create `friendships` table**
  - `user_id` (foreign key, indexed)
  - `friend_id` (foreign key, indexed)
  - `status` (enum: pending, accepted, declined)
  - `created_at`, `updated_at`, `archived_at`
  - Unique constraint on (user_id, friend_id)
  - Check constraint: user_id ≠ friend_id
  - Composite index on (user_id, status)

- [ ] **Migration: Create `playlist_invitations` table**
  - `playlist_id` (foreign key, indexed)
  - `inviter_id` (foreign key to users)
  - `invitee_id` (foreign key to users, nullable)
  - `invitee_email` (string, indexed)
  - `status` (enum: pending, accepted, archived)
  - `token` (string, unique, indexed) - for email invitation links
  - `invited_at`, `accepted_at`, `archived_at`
  - `created_at`, `updated_at`
  - Unique constraint on (playlist_id, invitee_id)
  - Index on (invitee_email, status)
  - Index on token

- [ ] **Migration: Create `playlist_watchers` table**
  - `playlist_id` (foreign key, indexed)
  - `user_id` (foreign key, indexed)
  - `role` (enum: owner, member)
  - `joined_at`, `left_at` (nullable)
  - `created_at`, `updated_at`, `archived_at`
  - Unique constraint on (playlist_id, user_id) where archived_at IS NULL
  - Composite index on (playlist_id, archived_at)
  - Composite index on (user_id, archived_at)

- [ ] **Migration: Create `activity_interests` table**
  - `activity_id` (foreign key, indexed)
  - `user_id` (foreign key, indexed)
  - `playlist_id` (foreign key, indexed)
  - `interest_level` (integer)
  - `created_at`, `updated_at`, `archived_at`
  - Check constraint: interest_level BETWEEN 1 AND 5
  - Unique constraint on (activity_id, user_id, playlist_id) where archived_at IS NULL
  - Composite index on (activity_id, playlist_id)
  - Index on user_id

- [ ] **Migration: Add automatic playlist_watchers for existing playlists**
  - Data migration to create owner records for all existing playlists

### 1.2 Models

- [ ] **Create `Friendship` model**
  - Belongs to user
  - Belongs to friend (class_name: 'User')
  - Validations: user_id != friend_id, presence of both IDs
  - Scopes: active, pending, accepted
  - Method: `accept!`, `decline!`, `archive!`
  - Method: `reciprocal` (find reverse friendship)

- [ ] **Create `PlaylistInvitation` model**
  - Belongs to playlist
  - Belongs to inviter (class_name: 'User')
  - Belongs to invitee (class_name: 'User', optional: true)
  - Validations: presence of playlist_id, inviter_id, invitee_email
  - Validations: email format for invitee_email
  - Callbacks: `before_create :generate_token`
  - Scopes: pending, accepted, archived
  - Methods: `accept!(user)`, `archive!`
  - Method: `find_or_create_invitee_user`

- [ ] **Create `PlaylistWatcher` model**
  - Belongs to playlist
  - Belongs to user
  - Validations: presence of playlist_id, user_id
  - Validations: role in ['owner', 'member']
  - Scopes: active, owners, members
  - Methods: `leave!`, `owner?`, `member?`
  - Callback: `set_joined_at` on create

- [ ] **Create `ActivityInterest` model**
  - Belongs to activity
  - Belongs to user
  - Belongs to playlist
  - Validations: interest_level between 1-5
  - Validations: presence of activity_id, user_id, playlist_id
  - Validations: uniqueness of activity_id scoped to user_id and playlist_id
  - Scopes: for_playlist, recent
  - Method: `self.average_for_activity(activity, playlist)`

- [ ] **Update `Playlist` model**
  - Add: `has_many :watchers, class_name: 'PlaylistWatcher'`
  - Add: `has_many :watching_users, through: :watchers, source: :user`
  - Add: `has_many :invitations, class_name: 'PlaylistInvitation'`
  - Add: `has_many :activity_interests, through: :activities`
  - Add method: `owner?(user)` - check if user is owner
  - Add method: `watched_by?(user)` - check if user is watcher
  - Add callback: `after_create :create_owner_watcher`

- [ ] **Update `User` model**
  - Add: `has_many :friendships`
  - Add: `has_many :friends, through: :friendships`
  - Add: `has_many :playlist_watchers`
  - Add: `has_many :watched_playlists, through: :playlist_watchers, source: :playlist`
  - Add: `has_many :sent_invitations, class_name: 'PlaylistInvitation', foreign_key: 'inviter_id'`
  - Add: `has_many :received_invitations, class_name: 'PlaylistInvitation', foreign_key: 'invitee_id'`
  - Add: `has_many :activity_interests`
  - Add method: `friend_with?(other_user)`
  - Add method: `watching_playlists` - active watched playlists

- [ ] **Update `Activity` model**
  - Add: `has_many :activity_interests`
  - Add method: `average_interest(playlist:)` - calculate average interest
  - Add method: `interest_distribution(playlist:)` - hash of rating counts
  - Add method: `watchers_who_rated(playlist:)` - users who rated this activity

### 1.3 Tests (Models)

- [ ] **Test `Friendship` model**
  - Valid creation with user and friend
  - Invalid with same user_id and friend_id
  - Status transitions (pending → accepted, pending → declined)
  - Scopes (active, pending, accepted)
  - `reciprocal` method finds reverse friendship

- [ ] **Test `PlaylistInvitation` model**
  - Valid creation with required fields
  - Auto-generates unique token on create
  - Invalid without invitee_email
  - `accept!` changes status and sets accepted_at
  - `archive!` changes status and sets archived_at
  - Cannot accept same invitation twice

- [ ] **Test `PlaylistWatcher` model**
  - Valid creation with playlist and user
  - Role must be owner or member
  - `leave!` sets left_at and archived_at
  - Scopes (active, owners, members) work correctly
  - Cannot create duplicate watcher for same playlist/user

- [ ] **Test `ActivityInterest` model**
  - Valid creation with rating 1-5
  - Invalid with rating outside range
  - Uniqueness per activity/user/playlist combination
  - `average_for_activity` calculates correctly
  - Can update rating

- [ ] **Test `Playlist` model updates**
  - Automatically creates owner watcher on create
  - `owner?` returns true for playlist creator
  - `watched_by?` returns true for watchers
  - Associations work correctly

- [ ] **Test `User` model updates**
  - Friendships association works
  - `watching_playlists` excludes owned playlists
  - `friend_with?` method works correctly

---

## Phase 2: Friend Management (Week 2)

### 2.1 Authorization & Policies

- [ ] **Create `FriendshipPolicy` (Pundit)**
  - `create?` - any authenticated user
  - `destroy?` - only the friendship owner
  - `accept?` - only the friend_id user
  - `decline?` - only the friend_id user

- [ ] **Create `PlaylistWatcherPolicy`**
  - `index?` - watchers of the playlist
  - `destroy?` - playlist owner (removing others) OR the watcher themselves (leaving)
  - `show?` - watchers of the playlist

- [ ] **Update `PlaylistPolicy`**
  - `show?` - watchers of the playlist (not just owner)
  - `update?` - only playlist owner
  - `destroy?` - only playlist owner
  - `invite?` - only playlist owner

### 2.2 Controllers

- [ ] **Create `FriendshipsController`**
  - `index` - GET /friends - list user's friendships
  - `create` - POST /friendships - create friendship (search by email/username)
  - `destroy` - DELETE /friendships/:id - unfriend
  - `accept` - PATCH /friendships/:id/accept - accept friendship
  - `decline` - PATCH /friendships/:id/decline - decline friendship
  - Authorize with FriendshipPolicy
  - Strong params: friend_email or friend_username

- [ ] **Create `Playlists::WatchersController`**
  - Nested under playlists: `/playlists/:playlist_id/watchers`
  - `index` - GET - list watchers
  - `destroy` - DELETE /:id - remove watcher (owner) or leave (member)
  - Authorize with PlaylistWatcherPolicy

### 2.3 Views

- [ ] **Create `friends/index.html.erb`**
  - Title: "My Friends"
  - Search/add friend form (email or username)
  - List of current friends with avatars (if available)
  - Pending friend requests (sent)
  - Pending friend requests (received) with Accept/Decline buttons
  - Unfriend button for each friend
  - Empty state if no friends

- [ ] **Add friend search partial**
  - `friends/_search_form.html.erb`
  - Input for email/username
  - Submit button
  - Error display for "user not found"

### 2.4 Routes

- [ ] **Add friendship routes**
  ```ruby
  resources :friendships, only: [:index, :create, :destroy] do
    member do
      patch :accept
      patch :decline
    end
  end
  ```

- [ ] **Add playlist watcher routes**
  ```ruby
  resources :playlists do
    resources :watchers, only: [:index, :destroy], controller: 'playlists/watchers'
  end
  ```

### 2.5 Tests (Controllers & System)

- [ ] **Controller tests: `FriendshipsController`**
  - GET index returns user's friendships
  - POST create with valid email creates friendship
  - POST create with invalid email returns error
  - PATCH accept changes status to accepted
  - PATCH decline changes status to declined
  - DELETE destroy removes friendship
  - Authorization: cannot accept someone else's friendship

- [ ] **System test: Friend management flow**
  - User can add friend by email
  - User sees pending friendship
  - Friend can accept invitation
  - Friend can decline invitation
  - User can unfriend

---

## Phase 3: Playlist Invitations (Week 2-3)

### 3.1 Controllers

- [ ] **Create `Playlists::InvitationsController`**
  - Nested under playlists: `/playlists/:playlist_id/invitations`
  - `new` - GET - show invite form
  - `create` - POST - send invitation(s)
  - `index` - GET - list sent invitations for playlist
  - `destroy` - DELETE /:id - cancel pending invitation
  - Authorize: only playlist owner

- [ ] **Create `InvitationsController` (user-facing)**
  - `index` - GET /invitations - user's received invitations
  - `show` - GET /invitations/:token - view invitation detail
  - `accept` - PATCH /invitations/:token/accept
  - `archive` - PATCH /invitations/:token/archive

### 3.2 Views

- [ ] **Create `playlists/invitations/new.html.erb`**
  - Title: "Invite Friends to [Playlist Name]"
  - Form to select multiple friends (checkboxes or multi-select)
  - Option to invite by email (non-friends)
  - Submit button: "Send Invitations"
  - Back to playlist link

- [ ] **Create `playlists/invitations/index.html.erb`**
  - Title: "Invitations for [Playlist Name]"
  - Tabs: Pending / Accepted / Archived
  - List of invitations with status
  - Option to cancel pending invitations
  - Invitee name/email, date sent

- [ ] **Create `invitations/index.html.erb`**
  - Title: "My Playlist Invitations"
  - Tabs: Pending / Archived
  - Each invitation shows:
    - Playlist name
    - Inviter name
    - Activity count preview
    - Date invited
    - Accept / Archive buttons
  - Empty state if no invitations

- [ ] **Create `invitations/show.html.erb`**
  - Invitation detail (from email link)
  - Playlist preview (name, description, sample activities)
  - Inviter info
  - Large Accept / Decline buttons
  - Requires login if not authenticated

- [ ] **Update `playlists/show.html.erb`**
  - Add "Watchers" section showing avatars
  - Add "Invite Friends" button (if owner)
  - Show "X pending invitations" link (if owner)
  - Show "Leave Playlist" button (if member)

### 3.3 Mailers

- [ ] **Create `PlaylistInvitationMailer`**
  - `invitation_email(invitation)`
    - Subject: "[Inviter Name] invited you to [Playlist Name]"
    - Body: Personalized message, playlist info, accept link
    - Link: `/invitations/[token]`
    - Styled with action mailer template

- [ ] **Add mailer preview**
  - `test/mailers/previews/playlist_invitation_mailer_preview.rb`

### 3.4 Background Jobs

- [ ] **Create `SendPlaylistInvitationJob`**
  - Takes invitation_id
  - Sends email via `PlaylistInvitationMailer`
  - Updates invitation status if email fails
  - Enqueue in `PlaylistInvitation` after create

### 3.5 Routes

- [ ] **Add invitation routes**
  ```ruby
  resources :playlists do
    resources :invitations, only: [:new, :create, :index, :destroy], controller: 'playlists/invitations'
  end

  resources :invitations, only: [:index, :show], param: :token do
    member do
      patch :accept
      patch :archive
    end
  end
  ```

### 3.6 Tests

- [ ] **Controller tests: `Playlists::InvitationsController`**
  - POST create with friend IDs sends invitations
  - POST create enqueues email job
  - Cannot invite same user twice
  - Only owner can send invitations
  - DELETE destroy cancels invitation

- [ ] **Controller tests: `InvitationsController`**
  - GET index shows user's received invitations
  - GET show with valid token displays invitation
  - PATCH accept creates PlaylistWatcher and updates invitation
  - PATCH archive updates invitation status
  - Invalid token returns 404

- [ ] **Mailer tests**
  - Email is sent with correct subject
  - Email contains invitation link
  - Email contains playlist details

- [ ] **System test: Invitation flow**
  - Owner invites friend to playlist
  - Friend receives email (check email sent)
  - Friend accepts invitation
  - Friend becomes watcher
  - Friend can see playlist activities

---

## Phase 4: Activity Interest Ratings (Week 3-4)

### 4.1 Controllers

- [ ] **Create `ActivityInterestsController`**
  - Nested under activities: `/activities/:activity_id/interests`
  - `create` - POST - rate activity (requires playlist_id param)
  - `update` - PATCH /:id - update rating
  - `destroy` - DELETE /:id - remove rating
  - `index` - GET - view all ratings for activity (filtered by playlist)
  - Authorize: only watchers of the playlist can rate

- [ ] **Create `Activities::InterestAnalyticsController`**
  - `show` - GET /activities/:activity_id/interest_analytics?playlist_id=X
  - Returns JSON with:
    - Average interest
    - Rating distribution
    - Individual ratings (if watcher)

### 4.2 Views

- [ ] **Create `activities/_interest_widget.html.erb` partial**
  - Visual 1-5 scale (stars, buttons, or slider)
  - Shows current user's rating (highlighted)
  - Shows average rating below
  - Click to rate/update
  - Stimulus controller for interaction

- [ ] **Create `activities/_interest_summary.html.erb` partial**
  - Average interest score (large)
  - Number of watchers who rated
  - Rating distribution (histogram or bars)
  - List of individual ratings (avatar + name + rating)

- [ ] **Update `activities/show.html.erb`**
  - Add interest widget at top (if user is watcher)
  - Add "Interest from Watchers" section
  - Link to detailed interest analytics

- [ ] **Update `playlists/show.html.erb`**
  - Show mini interest widget for each activity in list
  - Show average interest score next to activity name

### 4.3 Stimulus Controllers

- [ ] **Create `interest_rating_controller.js`**
  - Handles click on rating scale (1-5)
  - Submits AJAX request to create/update interest
  - Updates UI optimistically
  - Handles errors and rollback
  - Shows loading state

- [ ] **Create `interest_analytics_controller.js`**
  - Fetches interest analytics via AJAX
  - Displays modal or inline view
  - Updates when new ratings come in (optional: polling or turbo streams)

### 4.4 Turbo Streams (Optional)

- [ ] **Add Turbo Stream for real-time interest updates**
  - Broadcast to playlist watchers when interest is created/updated
  - Update interest summary in real-time
  - Use `turbo_stream_from` in view

### 4.5 Routes

- [ ] **Add interest routes**
  ```ruby
  resources :activities do
    resources :interests, only: [:create, :update, :destroy, :index], controller: 'activity_interests'
    resource :interest_analytics, only: [:show], controller: 'activities/interest_analytics'
  end
  ```

### 4.6 Tests

- [ ] **Controller tests: `ActivityInterestsController`**
  - POST create with valid rating (1-5) creates interest
  - POST create with invalid rating returns error
  - POST create without watcher access is unauthorized
  - PATCH update changes rating
  - DELETE destroy removes rating
  - GET index returns all ratings for activity in playlist

- [ ] **System test: Interest rating flow**
  - Watcher visits activity page
  - Watcher clicks on rating scale (e.g., 4 stars)
  - Rating is saved and displayed
  - Watcher can update rating
  - Other watchers see updated average

- [ ] **JavaScript test: interest_rating_controller**
  - Clicking rating sends POST request
  - UI updates optimistically
  - Error handling works

---

## Phase 5: Permissions & Authorization (Week 4)

### 5.1 Policy Enforcement

- [ ] **Update `PlaylistPolicy`**
  - `show?` - watchers only
  - `edit?` / `update?` - owner only
  - `destroy?` - owner only
  - `invite?` - owner only

- [ ] **Update `ActivityPolicy`**
  - `show?` - watchers of playlists containing this activity
  - `edit?` / `update?` - activity owner only
  - `destroy?` - activity owner only

- [ ] **Create `ActivityInterestPolicy`**
  - `create?` - watchers of the playlist
  - `update?` - interest owner only
  - `destroy?` - interest owner only
  - `index?` - watchers of the playlist

### 5.2 Authorization Checks

- [ ] **Add authorization helper methods**
  - `ApplicationController#current_user_watches?(playlist)`
  - `ApplicationController#current_user_owns?(playlist)`
  - Add to ApplicationController for use in views

- [ ] **Add before_action filters**
  - Ensure all playlist/activity actions check watcher status
  - Add `authorize @resource` to all controller actions

### 5.3 View Guards

- [ ] **Update navigation**
  - Show "My Playlists" and "Watching" as separate tabs
  - Hide invite button for non-owners
  - Hide edit/delete buttons for non-owners

- [ ] **Add conditional rendering**
  - Interest widget only shows for watchers
  - Activity edit buttons only for owners
  - Playlist settings only for owners

### 5.4 Tests

- [ ] **Policy tests**
  - Non-watchers cannot view playlist
  - Non-owners cannot edit playlist
  - Non-watchers cannot rate activities
  - Watchers can rate activities

- [ ] **System test: Authorization**
  - Non-watcher cannot access playlist URL
  - Non-watcher cannot rate activity
  - Member cannot edit playlist
  - Member can leave playlist

---

## Phase 6: UI/UX Polish (Week 4-5)

### 6.1 Navigation & Discoverability

- [ ] **Update main navigation**
  - "Friends" link in nav
  - "Invitations" link with badge showing pending count

- [ ] **Update `playlists/index.html.erb`**
  - Tabs: "My Playlists" / "Watching"
  - Show watcher count on each playlist card
  - Show interest engagement metric (% activities rated)

- [ ] **Create dashboard widget**
  - "Pending Invitations" widget on home page
  - "Recent Activity" widget (friends joining/leaving playlists)

### 6.2 Notifications

- [ ] **Add notification system (simple)**
  - Model: `Notification` (user_id, type, message, read_at)
  - Notification types:
    - friend_request_received
    - playlist_invitation_received
    - invitation_accepted
    - watcher_joined
    - watcher_left

- [ ] **Notification bell UI**
  - Icon in header with unread count
  - Dropdown showing recent notifications
  - Mark as read functionality

### 6.3 Email Notifications

- [ ] **Create additional mailer actions**
  - `PlaylistInvitationMailer#invitation_accepted`
  - `FriendshipMailer#friend_request_received`
  - `PlaylistMailer#watcher_joined`
  - `PlaylistMailer#watcher_left`

- [ ] **Add email preference settings**
  - User settings page to opt-in/out of emails
  - Store preferences in User model

### 6.4 Visual Design

- [ ] **Style friend list**
  - Use Tailwind for consistent styling
  - Avatar placeholders for users without avatars
  - Status badges (pending, accepted)

- [ ] **Style invitation UI**
  - Card-based layout for invitations
  - Clear CTA buttons
  - Responsive design

- [ ] **Style interest widget**
  - Make rating scale visually appealing
  - Use colors to indicate levels (red=low, green=high)
  - Smooth animations on interaction

- [ ] **Style watcher list**
  - Avatar grid layout
  - Tooltips showing names
  - Owner badge for playlist creator

### 6.5 Error Handling & Edge Cases

- [ ] **Handle edge cases**
  - User invites someone who's already a watcher (show helpful message)
  - User tries to leave a playlist they own (prevent or show error)
  - User tries to rate an activity twice (update instead of error)
  - Invitation token expired/invalid (clear error page)

- [ ] **Add flash messages**
  - Success messages for all actions
  - Error messages with helpful guidance
  - Use Turbo for seamless flash display

### 6.6 Accessibility

- [ ] **Ensure WCAG compliance**
  - Proper ARIA labels on all interactive elements
  - Keyboard navigation for rating widget
  - Screen reader friendly interest summaries
  - Color contrast meets AA standards

- [ ] **Test with axe-core-capybara**
  - Add accessibility system tests
  - Fix any violations

---

## Phase 7: Testing & Quality Assurance (Week 5)

### 7.1 Test Coverage

- [ ] **Ensure 90%+ test coverage**
  - Run `bin/rails test` and check SimpleCov report
  - Add missing unit tests
  - Add missing integration tests

- [ ] **System tests for all major flows**
  - Complete friend workflow
  - Complete invitation workflow
  - Complete interest rating workflow
  - Complete leave/remove watcher workflow

### 7.2 Performance Testing

- [ ] **Load testing**
  - Test playlist with 50+ watchers
  - Test activity with 100+ interest ratings
  - Ensure queries are optimized (use bullet gem)

- [ ] **Query optimization**
  - Eager load watchers on playlist show
  - Eager load interests on activity show
  - Add database indexes where needed

### 7.3 Security Audit

- [ ] **Security review**
  - Run Brakeman
  - Check for N+1 authorization bypasses
  - Ensure all endpoints are authorized
  - Check for mass assignment vulnerabilities

### 7.4 Code Quality

- [ ] **Run RuboCop**
  - Fix all offenses
  - Ensure consistent code style

- [ ] **Run Reek**
  - Address code smells
  - Refactor complex methods

- [ ] **Code review checklist**
  - All methods under 10 lines
  - No duplication
  - Clear variable names
  - Proper error handling

---

## Phase 8: Documentation & Launch Prep (Week 5)

### 8.1 User Documentation

- [ ] **Create user guide**
  - How to add friends
  - How to invite friends to playlists
  - How to rate activities
  - How to leave a playlist

- [ ] **Add onboarding tutorial**
  - First-time user walkthrough
  - Interactive tooltips
  - Sample data for new users

### 8.2 Developer Documentation

- [ ] **Update README**
  - Document new models
  - Document invitation flow
  - Document authorization setup

- [ ] **Add inline documentation**
  - YARD docs for complex methods
  - Comments explaining business logic

### 8.3 Deployment Checklist

- [ ] **Database migrations**
  - Test migrations on staging
  - Prepare rollback plan
  - Estimate migration time

- [ ] **Background jobs**
  - Ensure Solid Queue is running
  - Test email delivery

- [ ] **Environment variables**
  - Add any new ENV vars to production
  - Update credentials if needed

- [ ] **Feature flag (optional)**
  - Add feature flag to gate new features
  - Allow gradual rollout

### 8.4 Launch

- [ ] **Deploy to staging**
  - Full smoke test on staging
  - Test with real users

- [ ] **Deploy to production**
  - Run migrations
  - Monitor error logs
  - Monitor performance

- [ ] **Announce feature**
  - Email to existing users
  - Blog post or release notes
  - In-app announcement

---

## Dependencies & Blockers

### External Dependencies
- None (all Rails stack)

### Internal Dependencies
- User authentication (existing)
- Playlist model (existing)
- Activity model (existing)

### Potential Blockers
- Decision on friendship model (bidirectional vs follow)
- Email delivery setup (SMTP configuration)
- Real-time updates (optional, can be deferred)

---

## Metrics & Monitoring

### Key Metrics to Track
- Number of friendships created per day
- Invitation send rate
- Invitation acceptance rate
- Average interest ratings per activity
- Number of active watchers per playlist
- Time to accept invitation (latency)

### Monitoring
- Set up error tracking for invitation flow
- Monitor background job failures
- Track email delivery rates
- Set up alerts for authorization errors

---

## Post-Launch Iteration

### Phase 2 Features (Future)
- Real-time interest updates via Turbo Streams
- Bulk friend imports
- Friend suggestions
- Public/discoverable playlists
- Comments on activities
- Richer notification system

### Optimization
- Caching of interest aggregations
- GraphQL API for mobile app (future)
- Webhook support for external integrations
