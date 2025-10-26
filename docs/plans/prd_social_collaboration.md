# PRD: Social & Collaboration Features

**Version:** 1.0
**Status:** Draft
**Last Updated:** 2025-10-09
**Owner:** Product Team

---

## 1. Overview

### Problem Statement
Currently, Sidewalks is a single-user application where users can create playlists and activities. However, many activities are social in nature and benefit from coordination with friends. Users need the ability to:
- Share playlists with friends
- Gauge interest levels from multiple participants
- Manage who can view and participate in activities

### Goals
Enable collaborative activity planning by allowing users to invite friends to playlists, express interest in activities, and coordinate social events effectively.

### Success Metrics
- Number of playlist invitations sent per user
- Invitation acceptance rate
- Number of active "Playlist Watchers" per playlist
- Interest ratings submitted per activity
- Friend engagement rate (active watchers / invited friends)

---

## 2. User Stories

### As a Playlist Owner
- I want to invite friends to my playlist so they can see the activities I'm planning
- I want to see who has accepted my invitation and is watching my playlist
- I want to see interest levels from all watchers for each activity
- I want to remove watchers who are no longer participating

### As an Invited Friend
- I want to accept or decline playlist invitations
- I want to archive invitations I'm not interested in without accepting
- I want to express my interest in specific activities on a scale
- I want to pause a playlist when I temporarily want to opt-out of invites and planning
- I want to leave a playlist when I'm no longer interested

### As a Playlist Watcher
- I want to view all activities in playlists I'm watching
- I want to rate my interest in activities from 1-5
- I want to see what other watchers' interest levels are
- I want to track which playlists I'm actively watching

---

## 3. Functional Requirements

### 3.1 Friend Relationships
- **FR-1.1:** Users can connect with other users as "friends"
- **FR-1.2:** Friend relationships are bidirectional (if A friends B, then B friends A)
- **FR-1.3:** Users can search for friends by email or username
- **FR-1.4:** Users can view their list of friends
- **FR-1.5:** Users can unfriend other users

### 3.2 Playlist Invitations
- **FR-2.1:** Playlist owners can invite friends to their playlists
- **FR-2.2:** Invitations can be sent via email or in-app notification
- **FR-2.3:** Invited users receive notification of the invitation
- **FR-2.4:** Invited users can accept the invitation (becomes a Watcher)
- **FR-2.5:** Invited users can archive/decline the invitation
- **FR-2.6:** Playlist owners can see invitation status (pending, accepted, archived)
- **FR-2.7:** Playlist owners can cancel pending invitations
- **FR-2.8:** Users cannot invite the same friend twice to the same playlist

### 3.3 Playlist Watchers
- **FR-3.1:** Playlist creators are automatically watchers of their own playlists
- **FR-3.2:** Users who accept playlist invitations become "Playlist Watchers"
- **FR-3.3:** Watchers can view all activities in the playlist
- **FR-3.4:** Watchers can leave a playlist at any time
- **FR-3.5:** Playlist owners can remove watchers from their playlists
- **FR-3.6:** All watchers can see the list of other watchers on the playlist

### 3.4 Activity Interest Ratings
- **FR-4.1:** Any Playlist Watcher can rate their interest in an activity
- **FR-4.2:** Interest is expressed on a scale of 1-5 (1=low interest, 5=high interest)
- **FR-4.3:** Each watcher can only have one interest rating per activity
- **FR-4.4:** Watchers can update their interest rating at any time
- **FR-4.5:** Watchers can remove their interest rating
- **FR-4.6:** All watchers can see aggregated interest data:
  - Average interest score
  - Number of watchers who have rated
  - Distribution of ratings (optional: individual ratings by watcher)
- **FR-4.7:** Activity owners can see individual interest ratings from all watchers

---

## 4. Non-Functional Requirements

### Performance
- **NFR-1:** Invitation emails should be sent within 5 seconds of user action
- **NFR-2:** Interest rating updates should be reflected in real-time for all watchers
- **NFR-3:** Playlist watcher lists should load in under 500ms

### Security & Privacy
- **NFR-4:** Users can only invite their friends to playlists
- **NFR-5:** Only playlist watchers can view activities and interest ratings
- **NFR-6:** Users cannot access playlists they haven't been invited to
- **NFR-7:** All playlist access must be authenticated

### Scalability
- **NFR-8:** System should support up to 100 watchers per playlist
- **NFR-9:** System should support up to 1000 activities per playlist

### User Experience
- **NFR-10:** Invitation flow should be completable in under 3 clicks
- **NFR-11:** Interest rating should be updatable with a single interaction
- **NFR-12:** UI should clearly distinguish between owned playlists and watched playlists

---

## 5. Data Model Requirements

### New Tables

#### `friendships`
- `id` (primary key)
- `user_id` (foreign key → users)
- `friend_id` (foreign key → users)
- `status` (enum: pending, accepted, declined)
- `created_at`
- `updated_at`
- `archived_at`
- **Constraints:**
  - Unique constraint on (user_id, friend_id)
  - Check constraint: user_id ≠ friend_id

#### `playlist_invitations`
- `id` (primary key)
- `playlist_id` (foreign key → playlists)
- `inviter_id` (foreign key → users)
- `invitee_id` (foreign key → users)
- `status` (enum: pending, accepted, archived)
- `accepted_at`
- `archived_at`
- `created_at`
- `updated_at`
- **Constraints:**
  - Unique constraint on (playlist_id, invitee_id)

#### `playlist_watchers`
- `id` (primary key)
- `playlist_id` (foreign key → playlists)
- `user_id` (foreign key → users)
- `role` (enum: owner, watcher)
- `joined_at`
- `created_at`
- `updated_at`
- `archived_at` (for soft-delete when leaving)
- **Constraints:**
  - Unique constraint on (playlist_id, user_id, archived_at)

#### `activity_interests`
- `id` (primary key)
- `activity_id` (foreign key → activities)
- `user_id` (foreign key → users)
- `playlist_id` (foreign key → playlists) # for context
- `interest_level` (integer, 1-5)
- `created_at`
- `updated_at`
- `archived_at`
- **Constraints:**
  - Check constraint: interest_level BETWEEN 1 AND 5
  - Unique constraint on (activity_id, user_id, playlist_id)

---

## 6. User Interface Requirements

### 6.1 Playlist Show Page (Enhanced)
- Display list of current watchers with avatars
- "Invite Friends" button
- Show invitation count (pending/accepted)
- For each activity, display:
  - Interest rating widget (1-5 stars/scale)
  - Aggregate interest score
  - Number of watchers who rated
  - "View All Ratings" link (shows breakdown)

### 6.2 Playlist Invitations Page
- List of pending invitations sent
- List of accepted invitations
- Ability to cancel pending invitations
- Search/select friends to invite

### 6.3 My Invitations Page
- List of pending playlist invitations received
- Accept/Archive buttons for each
- Preview of playlist details
- List of playlists I'm watching (not owner)
- "Leave Playlist" option for each

### 6.4 Friends Management Page
- List of current friends
- Add friend by email/username
- Unfriend option
- Friend request status

### 6.5 Activity Interest Widget
- Visual representation of 1-5 scale (stars, slider, or buttons)
- One-click to set/update rating
- Display of current user's rating
- Display of aggregate statistics

---

## 7. API/Integration Requirements

### Email Notifications
- Playlist invitation email template
- Friend request email template
- Activity interest digest email (optional)

### Real-time Updates (Optional Phase 2)
- WebSocket/Turbo Streams for live interest rating updates
- Notification badges for new invitations

---

## 8. Business Rules

### BR-1: Friendship Requirements
- Users must be friends before playlist invitations can be sent
- Alternatively: Allow direct invitation by email (auto-creates friendship)

### BR-2: Ownership Rules
- Playlist creators cannot leave their own playlists
- Playlist creators maintain "owner" role even if they invite others

### BR-3: Interest Rating Visibility
- Interest ratings are only visible to watchers of that playlist
- Activity owners (across all playlists) can see all ratings for their activities

### BR-4: Invitation Expiry
- Playlist invitations do not expire (Phase 1)
- Optional: 30-day expiry for pending invitations (Phase 2)

### BR-5: Deletion Cascade
- If a playlist is deleted, all invitations and watchers are archived
- If a user is deleted, their friendships and watcher relationships are archived
- Interest ratings are preserved for historical data

---

## 9. Technical Considerations

### Technology Stack
- **Backend:** Rails 8, PostgreSQL
- **Frontend:** Turbo Rails, Stimulus
- **Styling:** Tailwind CSS
- **Background Jobs:** Solid Queue (for email sending)

### Performance Optimizations
- Eager loading of watchers and interest ratings on playlist pages
- Database indexes on:
  - `playlist_watchers.playlist_id`
  - `activity_interests.activity_id`
  - `activity_interests.playlist_id`
  - `friendships.user_id`
  - Composite indexes where applicable

### Security Considerations
- Authorize all playlist access through Watcher membership
- Use Pundit or similar for authorization policies
- Sanitize user inputs for friend search

---

## 10. Out of Scope (Future Phases)

- Direct messaging between watchers
- Comments on activities
- Activity scheduling/voting on specific dates
- Push notifications
- Mobile app
- Public/discoverable playlists
- Watcher permission levels (view-only vs can-edit)
- Bulk friend imports from contacts
- Friend suggestions/recommendations

---

## 11. Open Questions

1. **Friendship Model:** Should we require bidirectional friendship, or allow following/followers model?
2. **Email vs In-App:** Should invitations be email-only, in-app only, or both?
3. **Interest Visibility:** Should individual interest ratings be visible to all watchers, or only aggregated?
4. **Invitation Limit:** Should there be a limit on how many people can be invited to a single playlist?
5. **Notification Preferences:** Should users be able to control what notifications they receive?
6. **Default Interest:** When a new activity is added to a watched playlist, should watchers be notified? Auto-assigned a default interest?

---

## 12. Success Criteria & Launch Readiness

### Minimum Viable Product (MVP)
- ✅ Users can add friends
- ✅ Playlist owners can invite friends to playlists
- ✅ Invited users can accept or decline invitations
- ✅ Watchers can view playlist activities
- ✅ Watchers can rate their interest (1-5) on activities
- ✅ Watchers can see aggregate interest levels
- ✅ Watchers can leave playlists

### Phase 2 Enhancements
- Real-time interest rating updates
- Email notifications for invitations
- Interest rating history/analytics
- Friend suggestions
- Bulk invitations

### Testing Requirements
- Unit tests for all models and validations
- Controller tests for authorization
- System tests for invitation flow
- System tests for interest rating workflow
- Load testing for playlists with 50+ watchers

---

## 13. Timeline & Milestones

| Milestone | Description | Target |
|-----------|-------------|--------|
| Database Schema | Complete all migrations | Week 1 |
| Friend Management | Add/remove friends UI | Week 2 |
| Invitation System | Send/accept invitations | Week 3 |
| Watcher Management | View/leave playlists | Week 3 |
| Interest Ratings | Rate and view interests | Week 4 |
| Testing & Polish | Full test coverage | Week 5 |
| Beta Launch | Limited user testing | Week 6 |

---

## Appendix: Wireframes & Mockups
*[To be added: Figma links or embedded wireframes]*

## Appendix: Technical Architecture Diagram
*[To be added: Database ERD, system architecture]*
