# Claude Todos - Sidewalks v0 Implementation

## Progress Tracking
Started: 2025-09-16
Focus: Google Calendar Integration Priority

## Current Status
- [x] Planning phase complete
- [ ] Foundation models created
- [ ] Google Calendar integration implemented
- [ ] Core activity system built
- [ ] Activity coordinator implemented

## Phase 1: Foundation Setup ⏳
- [ ] Set up User authentication (Devise or Rails built-in)
- [ ] Create development seed user (user@sidewalkshq.com)
- [ ] Create base Activity model with scheduling capabilities
- [ ] Create Playlist model
- [ ] Create ActivityPlaylist join model
- [ ] Set up proper database migrations with indexes
- [ ] Implement soft delete pattern (archived_at)

## Phase 2: Google Calendar Integration 🎯 (PRIORITY)
- [ ] Add Google Calendar gems to Gemfile
- [ ] Set up Google OAuth credentials in Rails credentials
- [ ] Create GoogleAccount model for secure token storage
- [ ] Implement OAuth flow for Google Calendar access
- [ ] Build Google Calendar API service classes
- [ ] Create calendar event CRUD operations
- [ ] Map Sidewalks activities to Google Calendar events
- [ ] Implement token refresh mechanism
- [ ] Support multiple Google calendars per user

## Phase 3: Core Activity System
- [ ] Activities controller with full CRUD
- [ ] Activity scheduling system (strict vs flexible times)
- [ ] Activity expiration/deadline handling
- [ ] Max frequency options implementation
- [ ] Playlists controller with full CRUD
- [ ] Activity-Playlist association management
- [ ] RESTful routes and proper authorization

## Phase 4: Activity Coordinator (Future)
- [ ] Coordinator algorithm for activity suggestions
- [ ] Calendar gap analysis (empty days)
- [ ] Interest and recency-based recommendations
- [ ] Max 3 activities per day constraint
- [ ] 4-weekend lookahead window
- [ ] Respect max frequency settings

## Notes
- Using Rails encrypted credentials for Google OAuth secrets
- Implementing secure token storage with refresh capability
- Building Google Calendar integration as core feature
- Following RESTful conventions throughout