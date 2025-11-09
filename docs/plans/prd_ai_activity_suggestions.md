# PRD: AI-Powered Activity Suggestion & Categorization

**Version:** 1.0
**Status:** Draft
**Last Updated:** 2025-11-08
**Owner:** Product Team

---

## 1. Overview

### Problem Statement
Creating activities in Sidewalks currently requires users to manually:
- Choose a schedule type (flexible, scheduled, deadline)
- Set specific times or deadlines
- Determine appropriate frequency settings
- Categorize the activity within playlists
- Understand optimal timing (seasons, days of week)

Additionally, users often discover events online (Eventbrite, Facebook Events, restaurant websites, concert venues) and must manually copy information into the app. This is tedious and error-prone.

This manual process is time-consuming and error-prone. Users may not know the best time of year for certain activities (e.g., "visit pumpkin patch" is best in October) or what day of week makes sense (e.g., "happy hour" is typically weekdays).

### Goals
Build an AI-powered system that allows users to:
1. **Natural Language Input**: Simply describe an activity in plain English
2. **URL/Link Extraction**: Paste a link to an event page and have details auto-extracted

The system will automatically:
- Extract activity details (name, description, location, dates, times)
- Categorize the activity type
- Suggest optimal scheduling parameters (time of year, day of week, time of day)
- Set appropriate schedule_type and frequency settings
- Populate the activity into the suggestion engine with smart defaults

### Success Metrics
- **User Adoption**: % of activities created via AI suggestion vs manual
- **Input Method Distribution**: % text input vs % URL input
- **Time Savings**: Average time to create activity (AI vs manual vs URL)
- **Accuracy**: % of AI-suggested parameters accepted without modification
- **URL Extraction Success Rate**: % of URLs successfully parsed and converted to activities
- **User Satisfaction**: NPS score for AI suggestion feature
- **Completion Rate**: % of AI-created activities that get scheduled and completed
- **Edit Rate**: % of AI suggestions that require user edits before saving
- **Platform Coverage**: % of URLs from supported platforms (Eventbrite, Meetup, etc.)

---

## 2. User Stories

### As a User
- I want to describe an activity in plain English (e.g., "Go apple picking with friends")
- I want to paste a URL to an event page and have it automatically extract details
- I want the system to work with popular event sites (Eventbrite, Facebook Events, Meetup, etc.)
- I want the system to extract event dates, times, and locations from URLs
- I want the system to automatically suggest the best time of year for this activity
- I want the system to suggest the best day of week and time of day
- I want the system to determine if this is a flexible, scheduled, or deadline-based activity
- I want to review and edit AI suggestions before creating the activity
- I want the system to suggest which playlist this activity belongs to
- I want to see the reasoning behind AI suggestions (transparency)
- I want to provide feedback to improve future suggestions

### As a Power User
- I want to use natural language shortcuts (e.g., "Add 'coffee with Sarah' every Tuesday morning")
- I want the AI to learn from my past scheduling patterns
- I want to override AI suggestions when I have specific preferences
- I want bulk activity creation via natural language lists

---

## 3. Functional Requirements

### 3.1 Natural Language Input
- **FR-1.1:** Users can enter free-form text describing an activity
- **FR-1.2:** System accepts input via textarea or voice input (Phase 2)
- **FR-1.3:** System provides example prompts to guide users
- **FR-1.4:** Input length: minimum 5 characters, maximum 500 characters
- **FR-1.5:** System validates input and requests clarification if ambiguous

**Example Inputs:**
```
"Go apple picking in October"
"Weekly happy hour on Fridays"
"Visit the new museum exhibit before it closes in March"
"Try that new Italian restaurant everyone's talking about"
"Weekend hiking trip when the weather gets warm"
```

### 3.2 URL/Link Extraction
- **FR-1.6:** Users can paste a URL to an event, venue, or activity page
- **FR-1.7:** System validates URL format and accessibility
- **FR-1.8:** System fetches webpage content (respects robots.txt, rate limits)
- **FR-1.9:** System extracts structured data using multiple methods:
  - **Schema.org Event markup** (JSON-LD, Microdata)
  - **Open Graph meta tags** (og:title, og:description, og:image)
  - **Twitter Card meta tags**
  - **iCal/ICS calendar data**
  - **AI-powered content extraction** (fallback for unstructured pages)

- **FR-1.10:** System handles popular event platforms:
  - Eventbrite events
  - Facebook Events (public events only)
  - Meetup.com events
  - Ticketmaster events
  - Concert/venue websites
  - Restaurant websites (OpenTable, Resy, etc.)
  - Museum/attraction websites

- **FR-1.11:** System extracts from URLs:
  - **Event Name**: Title of the event/activity
  - **Date & Time**: Specific event date(s) and time(s)
  - **Location**: Full address, venue name, coordinates
  - **Description**: Event details and highlights
  - **Price**: Ticket price or cost (if available)
  - **Images**: Event poster/thumbnail
  - **Organizer**: Who's hosting the event
  - **URL**: Original source link (for reference)

- **FR-1.12:** System handles edge cases:
  - Recurring events (weekly shows, monthly meetups)
  - Multi-day events (festivals, conferences)
  - TBD/flexible dates ("Summer 2026")
  - Sold-out events (mark as deadline-past)
  - Paywalled content (graceful degradation)

**Example URLs:**
```
https://www.eventbrite.com/e/summer-music-festival-2026-tickets
https://www.facebook.com/events/123456789
https://www.meetup.com/techstartups/events/298765432
https://sfmoma.org/exhibition/contemporary-art-exhibit
https://www.opentable.com/r/italian-bistro-san-francisco
```

### 3.3 AI Processing & Extraction
- **FR-2.1:** System uses LLM (Claude, GPT-4, etc.) to parse:
  - Natural language text input
  - Extracted content from URLs (when structured data is insufficient)
- **FR-2.2:** For URL inputs, system prioritizes structured data extraction:
  1. First, attempt Schema.org/OpenGraph parsing (fast, reliable)
  2. If insufficient, use AI to parse HTML content (slower, more flexible)
  3. Combine structured + AI data for best results
- **FR-2.3:** System extracts the following fields:
  - **Activity Name**: Short title (e.g., "Apple Picking")
  - **Description**: Expanded details about the activity
  - **Location**: If mentioned (address, venue, area)
  - **Duration**: Estimated time needed (in hours)
  - **Category/Tags**: Type of activity (food, outdoors, culture, social, etc.)

- **FR-2.3:** System generates structured JSON response with extracted data
- **FR-2.4:** System handles multiple activities in a single input (comma/newline separated)
- **FR-2.5:** System normalizes activity names (proper capitalization, no typos)

### 3.3 Intelligent Scheduling Analysis
- **FR-3.1:** System determines optimal **time of year** based on:
  - Activity type (seasonal activities)
  - Weather dependencies (outdoor vs indoor)
  - Cultural/holiday associations (pumpkin picking → fall)
  - Event-specific timing (museum exhibits, concerts with dates)

- **FR-3.2:** System suggests **day of week** based on:
  - Activity type (happy hour → weekdays, brunch → weekends)
  - Venue operating hours (if known)
  - Social context (group activities → weekends)
  - User's historical patterns (if available)

- **FR-3.3:** System suggests **time of day** based on:
  - Activity name keywords (breakfast, lunch, dinner, happy hour, nightlife)
  - Activity type (hiking → morning, concerts → evening)
  - Duration estimates (long activities → start earlier)

- **FR-3.4:** System determines **schedule_type**:
  - `flexible`: No specific timing mentioned, can happen anytime
  - `scheduled`: Specific time/date pattern mentioned ("every Friday at 5pm")
  - `deadline`: Time-sensitive or expiring event ("before March", "museum exhibit closes")

- **FR-3.5:** System suggests **max_frequency_days** based on:
  - Activity cost/effort (expensive activities → longer frequency)
  - Activity type (daily habits vs special occasions)
  - User preferences or explicit mentions ("weekly", "monthly")

### 3.4 Activity Auto-Population
- **FR-4.1:** System automatically sets these activity fields:
  - `name` (extracted activity title)
  - `description` (expanded details + AI-generated context)
  - `schedule_type` (flexible/scheduled/deadline)
  - `start_time` (if scheduled type, suggested time slot)
  - `end_time` (calculated from start_time + duration)
  - `deadline` (if deadline type, suggested date)
  - `max_frequency_days` (suggested frequency)
  - `suggested_months` (JSON array: [10] for October activities)
  - `suggested_days_of_week` (JSON array: [1,2,3,4,5] for weekdays)
  - `suggested_time_of_day` (enum: morning, afternoon, evening, night)

- **FR-4.2:** System suggests which **playlist** to add activity to:
  - Based on activity category/tags
  - Based on existing playlist names/themes
  - Default: "Uncategorized" if no good match

- **FR-4.3:** System provides **confidence scores** for each suggestion (0-100%)

### 3.5 User Review & Editing
- **FR-5.1:** System displays AI-generated suggestions in a review UI
- **FR-5.2:** All fields are editable before saving
- **FR-5.3:** User can see AI reasoning for each suggestion (tooltip/expandable)
- **FR-5.4:** User can accept all suggestions with one click
- **FR-5.5:** User can reject and revert to manual input
- **FR-5.6:** User can provide feedback ("This was helpful" / "This was wrong")
- **FR-5.7:** System saves AI suggestions vs final values for learning

### 3.6 Learning & Improvement
- **FR-6.1:** System tracks user edits to AI suggestions
- **FR-6.2:** System learns from user's scheduling patterns over time
- **FR-6.3:** System improves suggestions based on feedback
- **FR-6.4:** System A/B tests different prompt strategies
- **FR-6.5:** Admin dashboard shows AI accuracy metrics

---

## 4. Non-Functional Requirements

### Performance
- **NFR-1:** AI processing should complete in under 3 seconds for simple text inputs
- **NFR-2:** AI processing should complete in under 10 seconds for complex inputs or URLs
- **NFR-3:** URL fetching should timeout after 10 seconds
- **NFR-4:** System should handle concurrent AI requests (background job queue)
- **NFR-5:** Rate limit AI API calls to prevent abuse (10 requests/minute per user)
- **NFR-6:** Cache extracted URL metadata for 24 hours (same URL = instant results)

### Reliability
- **NFR-7:** Graceful degradation if AI service is unavailable (fallback to manual input)
- **NFR-8:** Retry logic for failed AI API calls (3 attempts with exponential backoff)
- **NFR-9:** Retry logic for failed URL fetches (2 attempts, then show error)
- **NFR-10:** Clear error messages if AI parsing fails or URL is inaccessible
- **NFR-11:** System should never create activity without user confirmation

### Security & Privacy
- **NFR-12:** User input sanitized before sending to AI service
- **NFR-13:** No sensitive user data sent to AI (PII, emails, phone numbers stripped)
- **NFR-14:** AI API keys stored in encrypted credentials
- **NFR-15:** Comply with AI service provider's terms of service
- **NFR-16:** User can opt-out of AI features and use manual input
- **NFR-17:** Validate URLs to prevent SSRF attacks (no localhost, internal IPs)
- **NFR-18:** Follow robots.txt rules when fetching URLs
- **NFR-19:** Set appropriate User-Agent header identifying the app

### Web Scraping Ethics & Compliance
- **NFR-20:** Respect robots.txt directives
- **NFR-21:** Rate limit URL fetches per domain (max 1 request/second per domain)
- **NFR-22:** Honor noindex/nofollow meta tags
- **NFR-23:** Implement polite crawling delays (1-2 seconds between requests)
- **NFR-24:** Cache fetched content to minimize repeat requests
- **NFR-25:** Provide clear User-Agent identifying app and purpose
- **NFR-26:** Include contact email in User-Agent for site owners

### Cost Management
- **NFR-27:** Estimate AI API costs per request
- **NFR-28:** Set monthly budget cap for AI API usage
- **NFR-29:** Log all AI requests for cost tracking
- **NFR-30:** Use caching for repeated similar inputs and URLs

### User Experience
- **NFR-31:** AI suggestions should feel magical but transparent
- **NFR-32:** Users should understand why AI made each suggestion
- **NFR-33:** UI should show processing state (loading spinner, progress)
- **NFR-34:** URL tab should auto-detect when user pastes URL in text field
- **NFR-35:** Show preview of fetched event (title, image) before extraction
- **NFR-36:** Mobile-responsive AI input interface with both tabs

---

## 5. Data Model Requirements

### New Tables

#### `ai_activity_suggestions`
Stores AI-generated suggestions for audit and learning.

- `id` (primary key)
- `user_id` (foreign key → users)
- `input_type` (enum: text, url) - Type of input provided
- `input_text` (text) - Original user input (natural language description)
- `source_url` (text) - URL if user provided a link
- `extracted_metadata` (jsonb) - Structured data from URL (Schema.org, OpenGraph, etc.)
- `model_used` (string) - AI model identifier (e.g., "gpt-4", "claude-3")
- `api_request` (jsonb) - Request payload sent to AI
- `api_response` (jsonb) - Raw AI response
- `processing_time_ms` (integer)
- `confidence_score` (decimal)
- `suggested_data` (jsonb) - Structured extracted data
  ```json
  {
    "name": "Apple Picking",
    "description": "Visit local orchard for apple picking",
    "schedule_type": "flexible",
    "suggested_months": [9, 10],
    "suggested_days_of_week": [6, 7],
    "suggested_time_of_day": "afternoon",
    "max_frequency_days": 365,
    "duration_hours": 2,
    "category": "outdoor_seasonal",
    "location": null,
    "reasoning": {
      "time_of_year": "Apple picking is a fall activity, peak season September-October",
      "day_of_week": "Weekend activity due to orchard hours and social nature",
      "time_of_day": "Afternoon recommended to avoid morning dew and crowds"
    }
  }
  ```
- `user_edits` (jsonb) - Fields user changed after review
- `final_activity_id` (foreign key → activities, nullable)
- `accepted` (boolean) - Whether user accepted and created activity
- `feedback` (text) - User feedback on suggestion quality
- `created_at`
- `updated_at`
- **Constraints:**
  - Index on (user_id, created_at)
  - Index on (accepted, created_at) for analytics

### Table Modifications

#### `activities` (add new columns)
- `ai_generated` (boolean, default: false) - Flag if created via AI
- `ai_suggestion_id` (foreign key → ai_activity_suggestions, nullable)
- `source_url` (text) - Original event/venue URL if created from link
- `image_url` (text) - Event poster/image URL
- `price` (decimal) - Ticket price or estimated cost
- `organizer` (string) - Event organizer or venue name
- `suggested_months` (integer array) - Best months: [1,2,12] for winter activities
- `suggested_days_of_week` (integer array) - Best days: [1-5] weekdays, [6,7] weekends
- `suggested_time_of_day` (enum: morning, afternoon, evening, night, anytime)
- `category_tags` (string array) - Tags: ["outdoor", "social", "food", "culture"]
- `event_metadata` (jsonb) - Additional structured event data (recurrence, capacity, etc.)

---

## 6. User Interface Requirements

### 6.1 AI Activity Input Page

**New "Quick Add with AI" Option:**
- Prominent button on activities index: **"Quick Add with AI ✨"**
- Modal or dedicated page with:
  - **Tab 1: Natural Language**
    - Large textarea for description
    - Character counter (5-500 chars)
    - Example prompts (rotating helpful examples)
  - **Tab 2: From URL**
    - URL input field with validation
    - "Paste event link" placeholder
    - Supported platforms: Eventbrite, Facebook Events, Meetup, etc.
    - Link icon preview of webpage
  - "Generate Activity" button (primary CTA)
  - "Use Manual Form" link (for advanced users)
  - Auto-detection: If user pastes URL in text field, suggest switching to URL tab

**Example Prompts Section (Text Tab):**
```
💡 Try these examples:
• "Weekend brunch at the new cafe downtown"
• "Go hiking when spring arrives"
• "Monthly game night with friends"
• "Try making homemade pasta before Christmas"
```

**Example URLs (URL Tab):**
```
💡 Paste any event link:
• Eventbrite: https://eventbrite.com/e/...
• Facebook Events: https://facebook.com/events/...
• Meetup: https://meetup.com/.../events/...
• Venue websites: Concert halls, museums, restaurants
```

### 6.2 AI Suggestion Review Page

**Layout:**
```
┌─────────────────────────────────────────────────┐
│ ✨ AI Suggestion Review                         │
│                                                 │
│ Your Input: "Go apple picking in October"      │
│                                                 │
│ ┌─────────────────────────────────────────┐    │
│ │ 📝 Activity Details                     │    │
│ │                                         │    │
│ │ Name: Apple Picking             [Edit] │    │
│ │ Description: Visit local orchard...     │    │
│ │                                         │    │
│ │ 📅 Scheduling                           │    │
│ │ Type: Flexible                          │    │
│ │ Best Months: September, October  ⓘ     │    │
│ │   → Why? Apple season peaks in fall    │    │
│ │                                         │    │
│ │ Best Days: Weekends              ⓘ     │    │
│ │   → Why? Orchards busier on weekends   │    │
│ │                                         │    │
│ │ Best Time: Afternoon             ⓘ     │    │
│ │   → Why? Avoid morning dew, crowds     │    │
│ │                                         │    │
│ │ Frequency: Once per year                │    │
│ │                                         │    │
│ │ 📂 Suggested Playlist: Seasonal Fun     │    │
│ │                                         │    │
│ │ Confidence: ████████░░ 85%              │    │
│ └─────────────────────────────────────────┘    │
│                                                 │
│ [✓ Create Activity]  [✏️ Edit Details]  [✗ Cancel] │
└─────────────────────────────────────────────────┘
```

**Features:**
- All fields editable inline
- Tooltips (ⓘ) explaining AI reasoning
- Confidence indicators
- Visual grouping (details, scheduling, categorization)
- Quick accept or detailed edit options

### 6.3 Activity Form Enhancement

**Hybrid Manual/AI Mode:**
- Existing manual form has "Get AI Suggestions" button
- User fills some fields manually, then asks AI to suggest rest
- AI augments partial data (e.g., user sets name, AI suggests scheduling)

### 6.4 Activity Detail Page Enhancement

**AI Attribution:**
- Badge showing "AI-suggested ✨" for AI-created activities
- Link to view original suggestion and user edits
- "This was created from: 'Go apple picking in October'"

---

## 7. Technical Architecture

### 7.1 AI Service Integration

**Option A: OpenAI GPT-4**
- Pros: Excellent natural language understanding, structured output mode
- Cons: Cost per request, rate limits, external dependency
- API: `https://api.openai.com/v1/chat/completions`

**Option B: Anthropic Claude (Recommended)**
- Pros: Better reasoning, tool use capabilities, transparent thinking
- Cons: Slightly higher cost, newer API
- API: `https://api.anthropic.com/v1/messages`

**Option C: Self-hosted (Ollama/Llama)**
- Pros: Free, no external dependency, privacy
- Cons: Requires GPU infrastructure, lower quality
- For later phase when scaling

**Recommended: Start with Claude, add OpenAI as fallback**

### 7.2 AI Prompt Engineering

**System Prompt Template:**
```ruby
SYSTEM_PROMPT = <<~PROMPT
  You are an AI assistant helping users plan activities and events.

  Your task is to extract structured information from natural language
  descriptions of activities and suggest optimal scheduling parameters.

  Current date: #{Date.today}
  Current season: #{current_season}
  User's timezone: #{user.timezone}
  User's location: #{user.location || 'Unknown'}

  Analyze the user's input and return a JSON object with these fields:
  - name: Short activity title (2-5 words)
  - description: Expanded description (1-2 sentences)
  - schedule_type: 'flexible' | 'scheduled' | 'deadline'
  - suggested_months: Array of month numbers (1-12) when activity is best
  - suggested_days_of_week: Array of day numbers (1=Mon...7=Sun)
  - suggested_time_of_day: 'morning' | 'afternoon' | 'evening' | 'night' | 'anytime'
  - max_frequency_days: Days between repetitions (7, 30, 90, 365, etc.)
  - duration_hours: Estimated duration in hours
  - category_tags: Array of tags ('outdoor', 'social', 'food', 'culture', etc.)
  - location: Extracted location if mentioned
  - confidence: 0-100 score for overall confidence
  - reasoning: Object explaining why each suggestion was made

  Be thoughtful about seasonal activities, cultural context, and practical
  considerations like weather, venue hours, and social norms.

  If the input is ambiguous, make reasonable assumptions but note lower confidence.
PROMPT

USER_PROMPT = "Activity description: #{user_input}"
```

### 7.3 Processing Flow

```
User submits natural language input
  ↓
Frontend validates input (5-500 chars)
  ↓
POST /activities/ai_suggest
  ↓
Background Job: AiActivitySuggestionJob
  ↓
  1. Sanitize input (remove PII)
  2. Build AI prompt with context
  3. Call AI API (Claude/GPT)
  4. Parse JSON response
  5. Validate extracted data
  6. Calculate confidence scores
  7. Save to ai_activity_suggestions table
  8. Broadcast results via Turbo Stream
  ↓
Frontend displays suggestion review UI
  ↓
User reviews/edits suggestions
  ↓
User clicks "Create Activity"
  ↓
POST /activities
  ↓
  1. Create activity with AI data + user edits
  2. Link to ai_activity_suggestions record
  3. Track user edits for learning
  4. Redirect to activity detail page
```

### 7.4 Caching Strategy

**Reduce AI API Costs:**
- Cache similar inputs: "Go apple picking" ≈ "Apple picking trip"
- Use fuzzy matching (Levenshtein distance) to find cached suggestions
- Cache TTL: 30 days
- Cache key: `ai_suggestion:#{normalized_input_hash}`

**Example:**
```ruby
class AiActivitySuggestionService
  def suggest(user_input)
    cache_key = "ai_suggestion:#{normalize_input(user_input)}"

    Rails.cache.fetch(cache_key, expires_in: 30.days) do
      call_ai_api(user_input)
    end
  end

  private

  def normalize_input(text)
    # Lowercase, remove punctuation, stem words
    text.downcase.gsub(/[^a-z0-9\s]/, '').split.sort.join(' ')
  end
end
```

---

## 8. AI Response Schema

### 8.1 Expected JSON Response Format

```json
{
  "name": "Apple Picking",
  "description": "Visit a local orchard to pick fresh apples during peak harvest season. Great activity for families or friends.",
  "schedule_type": "flexible",
  "suggested_months": [9, 10],
  "suggested_days_of_week": [6, 7],
  "suggested_time_of_day": "afternoon",
  "max_frequency_days": 365,
  "duration_hours": 2.5,
  "category_tags": ["outdoor", "seasonal", "family-friendly", "food"],
  "location": null,
  "confidence": 90,
  "reasoning": {
    "time_of_year": "Apple picking season runs September through October in most regions. October is peak season.",
    "day_of_week": "Orchards are typically busiest on weekends when families can participate together.",
    "time_of_day": "Afternoon (1-4pm) avoids morning dew on apples and gives time for crowds to thin.",
    "frequency": "This is a seasonal activity best enjoyed once per year during harvest.",
    "schedule_type": "Marked as flexible since no specific date was mentioned, just a general timeframe."
  },
  "playlist_suggestion": {
    "name": "Seasonal Activities",
    "confidence": 75,
    "reasoning": "This activity is seasonal in nature and would fit well with other fall/seasonal events."
  }
}
```

### 8.2 Validation Rules

After receiving AI response, validate:
- `name`: 2-100 characters, not blank
- `schedule_type`: Must be one of: flexible, scheduled, deadline
- `suggested_months`: Array of integers 1-12
- `suggested_days_of_week`: Array of integers 1-7
- `suggested_time_of_day`: Must be valid enum value
- `max_frequency_days`: Integer > 0
- `duration_hours`: Decimal > 0
- `category_tags`: Array of strings
- `confidence`: Integer 0-100

If validation fails, use fallback values or prompt user for clarification.

---

## 9. Business Rules

### BR-1: AI Usage Limits
- Free tier: 10 AI suggestions per month
- Pro tier: Unlimited AI suggestions
- Rate limit: 10 requests per minute per user
- Daily quota: 100 requests per user

### BR-2: Data Quality
- AI confidence < 50%: Warn user, suggest manual input
- AI confidence 50-75%: Show review UI with emphasis on editing
- AI confidence > 75%: Encourage quick accept, but still reviewable

### BR-3: Fallback Behavior
- If AI service unavailable: Show manual form with message
- If AI parsing fails: Extract basic name/description, prompt manual scheduling
- If AI response invalid: Retry once, then fallback to manual

### BR-4: Learning & Feedback
- Track acceptance rate per confidence threshold
- Track which fields users most commonly edit
- Use feedback to adjust prompts and improve accuracy
- A/B test different prompt strategies

### BR-5: Privacy & Security
- Strip PII from input before sending to AI (emails, phone numbers, addresses)
- Don't send user's full activity history to AI (only metadata)
- Log AI requests but encrypt input_text at rest
- Allow users to delete AI suggestion history

---

## 10. Edge Cases & Error Handling

### Edge Case Scenarios

**EC-1: Vague Input**
```
Input: "Do something fun"
AI Response: High-level suggestions, low confidence
Action: Prompt user for more specificity
```

**EC-2: Multiple Activities in One Input**
```
Input: "Apple picking, pumpkin carving, and hayride"
AI Response: Split into 3 separate suggestions
Action: Show bulk review UI for all 3
```

**EC-3: Conflicting Constraints**
```
Input: "Outdoor ice skating in July"
AI Response: Flag seasonal mismatch, suggest alternative month
Action: Show warning, let user override
```

**EC-4: Deadline Activities with Past Dates**
```
Input: "Visit museum exhibit that closes in March" (current: April)
AI Response: Detect expired deadline
Action: Suggest removing deadline or finding alternative
```

**EC-5: Location-Specific Activities**
```
Input: "Go surfing" (user location: landlocked state)
AI Response: Note travel required or suggest alternative
Action: Add location field, warn about feasibility
```

**EC-6: Very Long Input (>500 chars)**
```
Action: Truncate input, show warning, ask user to shorten
```

**EC-7: Non-English Input**
```
Action: Detect language, attempt translation or show error
Phase 2: Multi-language support
```

### Error Handling

**EH-1: AI API Timeout**
```ruby
rescue Faraday::TimeoutError => e
  # Retry up to 3 times with exponential backoff
  # If all retries fail, return manual form
  flash[:error] = "AI suggestion is taking longer than expected. Please try again or use manual input."
end
```

**EH-2: AI API Rate Limit**
```ruby
rescue OpenAI::RateLimitError => e
  # Queue job for later retry
  flash[:warning] = "AI service is busy. Your request has been queued and you'll be notified when ready."
  AiActivitySuggestionJob.set(wait: 1.minute).perform_later(user.id, input_text)
end
```

**EH-3: Invalid JSON Response**
```ruby
rescue JSON::ParserError => e
  # Log error, attempt to extract partial data
  # Fallback to manual input if critical fields missing
  Sentry.capture_exception(e, extra: { ai_response: response.body })
  flash[:error] = "AI couldn't process your request. Please use manual input."
end
```

**EH-4: AI Service Unavailable**
```ruby
rescue Faraday::ConnectionFailed => e
  # Check if this is a recurring issue
  # Temporarily disable AI feature if multiple failures
  if AiServiceHealthCheck.failing?
    flash[:error] = "AI suggestions are temporarily unavailable. Please use manual input."
    redirect_to new_activity_path
  else
    retry_job
  end
end
```

---

## 11. Success Criteria & Launch Readiness

### Minimum Viable Product (MVP)

**Core Functionality:**
- ✅ Users can input natural language activity descriptions
- ✅ AI extracts basic fields: name, description, schedule_type
- ✅ AI suggests time of year (months) for seasonal activities
- ✅ AI suggests day of week based on activity type
- ✅ AI suggests time of day based on keywords
- ✅ Users can review and edit AI suggestions before saving
- ✅ System tracks AI vs manual creation rate
- ✅ Graceful fallback if AI service unavailable

**Quality Thresholds:**
- AI accuracy (fields accepted without edit): > 70%
- Response time (95th percentile): < 5 seconds
- Error rate: < 5%
- User satisfaction: > 4.0/5.0 rating

### Phase 2 Enhancements

**Advanced Features:**
- Voice input support (speech-to-text → AI)
- Bulk activity creation from lists
- Learning from user's historical patterns
- Multi-language support
- Playlist auto-categorization improvements
- Integration with activity coordinator for smart suggestions
- Calendar conflict detection during AI suggestion

**Learning & Optimization:**
- User feedback loop to improve prompts
- A/B testing different AI models (Claude vs GPT)
- Cost optimization through caching and batching
- Personalized prompts based on user preferences

---

## 12. Testing Requirements

### Unit Tests
- AI response parsing and validation
- Input sanitization (PII removal)
- Confidence score calculation
- Fallback logic when AI fails

### Integration Tests
- AI API integration (with mocked responses)
- Background job processing
- Caching behavior
- Error handling flows

### System Tests
- End-to-end AI suggestion flow
- User edits and saves activity
- Fallback to manual input
- Multiple activities in one input

### Performance Tests
- Response time under load
- Concurrent AI requests
- Cache hit rates
- API cost tracking

### AI Prompt Tests
- Test prompts against 50+ example inputs
- Validate accuracy of extracted fields
- Test edge cases (vague, conflicting, complex inputs)
- Compare Claude vs GPT-4 accuracy

---

## 13. Technical Considerations

### AI Model Selection Criteria

| Criteria | Claude 3.5 Sonnet | GPT-4 | Llama 3 (Self-hosted) |
|----------|-------------------|-------|------------------------|
| **Accuracy** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Cost** | $3/M input tokens | $10/M input tokens | Free (infra costs) |
| **Speed** | ~2s | ~3s | Variable |
| **Structured Output** | ✅ Tool use | ✅ JSON mode | ⚠️ Limited |
| **Reasoning** | ✅ Excellent | ✅ Good | ⚠️ Basic |
| **Rate Limits** | High | Medium | None |

**Recommendation:** Start with **Claude 3.5 Sonnet** for best quality/cost ratio.

### Cost Estimates

**Average AI Request:**
- Input tokens: ~500 (system prompt + user input + context)
- Output tokens: ~300 (JSON response + reasoning)
- Total: ~800 tokens per request

**Claude 3.5 Sonnet Pricing:**
- Input: $3 per million tokens
- Output: $15 per million tokens
- **Cost per request: ~$0.006** (less than 1 cent)

**Monthly Cost Estimates:**
- 100 users × 10 suggestions/month = 1,000 requests
- Cost: **$6/month**
- At scale (10,000 users): **$600/month**

**Optimization Strategies:**
- Caching similar requests: 30-50% cost reduction
- Batch processing: Minimal savings (requests are unique)
- Use smaller model for simple inputs: 50% cost reduction

### Latency Optimization

**Target: 95th percentile < 5 seconds**

1. **Background Processing:** Move AI call to Sidekiq job
2. **Caching:** Cache similar inputs (fuzzy matching)
3. **Progressive Enhancement:** Show manual form immediately, enhance with AI
4. **WebSockets:** Real-time updates when AI completes
5. **Timeouts:** 10-second timeout, fallback to manual

---

## 14. Timeline & Milestones

| Milestone | Description | Effort | Target |
|-----------|-------------|--------|--------|
| **Phase 1: MVP** | | | **6 weeks** |
| API Integration | Set up Claude API, basic prompt | 3 days | Week 1 |
| Parsing Logic | Extract fields from AI response | 3 days | Week 1 |
| Review UI | Suggestion review page | 5 days | Week 2 |
| Background Jobs | Async AI processing | 2 days | Week 2 |
| Error Handling | Fallbacks, retries, validation | 3 days | Week 3 |
| Activity Model Updates | New columns, migrations | 2 days | Week 3 |
| Integration Testing | AI flow testing, mocks | 5 days | Week 4 |
| Prompt Engineering | Optimize prompts, test accuracy | 5 days | Week 5 |
| UI Polish | Loading states, tooltips, help text | 3 days | Week 5 |
| Beta Testing | Internal testing, feedback | 1 week | Week 6 |
| **Phase 2: Enhancements** | | | **4 weeks** |
| Learning System | Track edits, improve prompts | 5 days | Week 7 |
| Caching | Implement fuzzy matching cache | 3 days | Week 8 |
| Bulk Creation | Multi-activity input | 5 days | Week 8-9 |
| Voice Input | Speech-to-text integration | 5 days | Week 9 |
| Analytics Dashboard | AI performance metrics | 3 days | Week 10 |
| Cost Optimization | Caching, batching, model selection | 2 days | Week 10 |

---

## 15. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **AI accuracy below 70%** | High | Medium | Extensive prompt testing, user feedback loop, allow manual override |
| **AI API costs exceed budget** | High | Medium | Implement caching, rate limiting, monthly caps, cost monitoring |
| **AI service downtime** | Medium | Low | Graceful fallback to manual input, queue jobs for retry, status page |
| **User privacy concerns** | High | Low | Strip PII, clear privacy policy, user consent, data retention policy |
| **Poor user adoption** | High | Medium | Onboarding tutorial, example prompts, clear value prop, gradual rollout |
| **Complex inputs fail** | Medium | High | Show confidence scores, guide users to simplify, offer manual option |
| **API rate limits** | Medium | Medium | Background jobs, queuing, exponential backoff, distribute across providers |
| **Inconsistent suggestions** | Medium | Medium | Prompt versioning, A/B testing, user feedback, continuous improvement |

---

## 16. Open Questions

1. **AI Provider:** Should we use Claude, GPT-4, or both? Start with one or multi-provider from day 1?
2. **User Onboarding:** How do we educate users about AI capabilities without overwhelming them?
3. **Feedback Mechanism:** Thumbs up/down, detailed form, or implicit (tracking edits)?
4. **Confidence Threshold:** Below what confidence should we not show suggestions?
5. **Playlist Categorization:** Should AI auto-add to playlists or always prompt user?
6. **Time Zone Handling:** How to handle "morning" across different time zones?
7. **Recurring Activities:** How to extract recurrence patterns from natural language?
8. **Multi-User Activities:** Should AI detect when activity mentions multiple people and suggest invites?
9. **Cost Limits:** What's the monthly AI budget? Per-user limits?
10. **Versioning:** How to handle prompt changes without breaking existing suggestions?

---

## 17. Out of Scope (Future Phases)

- **Phase 3+:**
  - Natural language queries ("What should I do this weekend?")
  - Conversational AI for activity planning
  - AI-generated activity ideas (not just parsing user input)
  - Image recognition for activity detection (user uploads photo)
  - Integration with external APIs (weather, events, restaurant reservations)
  - Collaborative AI suggestions (considering multiple users' preferences)
  - Predictive scheduling (AI suggests when you should do activity)
  - Sentiment analysis on activity descriptions
  - AI-powered playlist curation
  - Voice assistant integration (Alexa, Google Assistant)

---

## 18. Success Metrics Dashboard

### Key Metrics to Track

**Usage Metrics:**
- AI suggestions requested per day/week/month
- AI vs manual activity creation ratio
- Average suggestions per user
- Time spent on review UI

**Quality Metrics:**
- AI accuracy by field (% accepted without edit)
  - Name accuracy
  - Schedule type accuracy
  - Time of year accuracy
  - Day of week accuracy
  - Time of day accuracy
- Overall acceptance rate
- Edit rate by field
- User feedback ratings

**Performance Metrics:**
- AI response time (p50, p95, p99)
- Error rate
- Cache hit rate
- API timeout rate
- Background job processing time

**Business Metrics:**
- Cost per AI suggestion
- Monthly AI API spend
- ROI (time saved × user value)
- Feature adoption rate
- User retention (AI users vs non-AI users)

**Learning Metrics:**
- Accuracy improvement over time
- Most commonly edited fields
- Common failure patterns
- User feedback themes

---

## 19. Privacy & Compliance

### Data Handling
- **What we send to AI:**
  - Sanitized activity description (PII removed)
  - Current date/season/timezone (for context)
  - Activity category preferences (anonymized)

- **What we don't send:**
  - User's full name, email, phone
  - User's full activity history
  - Other users' data
  - Sensitive location data

### Data Retention
- AI suggestion records: Kept for 90 days for learning
- After 90 days: Anonymize or delete
- User can request immediate deletion of AI history
- Comply with GDPR/CCPA data deletion requests

### Terms of Service
- User consent required for AI processing
- Clear disclosure that AI is used
- Opt-out option available
- Transparency about AI limitations

---

## Appendix A: Example Inputs & Expected Outputs

### Example 1: Simple Seasonal Activity
**Input:** "Go apple picking in October"

**Expected Output:**
```json
{
  "name": "Apple Picking",
  "description": "Visit a local orchard to pick fresh apples during harvest season",
  "schedule_type": "flexible",
  "suggested_months": [9, 10],
  "suggested_days_of_week": [6, 7],
  "suggested_time_of_day": "afternoon",
  "max_frequency_days": 365,
  "duration_hours": 2.5,
  "category_tags": ["outdoor", "seasonal", "family-friendly"],
  "confidence": 92
}
```

### Example 2: Scheduled Recurring Activity
**Input:** "Weekly happy hour on Fridays at 5pm"

**Expected Output:**
```json
{
  "name": "Happy Hour",
  "description": "Weekly after-work drinks and socializing",
  "schedule_type": "scheduled",
  "start_time": "17:00",
  "suggested_months": [1,2,3,4,5,6,7,8,9,10,11,12],
  "suggested_days_of_week": [5],
  "suggested_time_of_day": "evening",
  "max_frequency_days": 7,
  "duration_hours": 2,
  "category_tags": ["social", "food_drink", "weekly"],
  "confidence": 95
}
```

### Example 3: Deadline Activity
**Input:** "Visit museum exhibit before it closes in March"

**Expected Output:**
```json
{
  "name": "Museum Exhibit Visit",
  "description": "See the current exhibit before it closes",
  "schedule_type": "deadline",
  "deadline": "2026-03-31",
  "suggested_months": [1, 2, 3],
  "suggested_days_of_week": [1,2,3,4,5,6,7],
  "suggested_time_of_day": "afternoon",
  "max_frequency_days": 90,
  "duration_hours": 2,
  "category_tags": ["culture", "indoor", "art"],
  "confidence": 88
}
```

### Example 4: Vague Input (Low Confidence)
**Input:** "Do something fun"

**Expected Output:**
```json
{
  "name": "Fun Activity",
  "description": "General entertainment or leisure activity",
  "schedule_type": "flexible",
  "suggested_months": [1,2,3,4,5,6,7,8,9,10,11,12],
  "suggested_days_of_week": [6, 7],
  "suggested_time_of_day": "anytime",
  "max_frequency_days": 7,
  "duration_hours": 2,
  "category_tags": ["general"],
  "confidence": 35,
  "reasoning": {
    "note": "Input is very vague. User should provide more specific details about what type of fun activity they have in mind."
  }
}
```

---

## Appendix B: AI Prompt Templates

### System Prompt (Full Version)

```
You are an intelligent activity planning assistant for Sidewalks, an app that helps users organize and schedule activities with friends.

## Your Task
Parse natural language descriptions of activities and extract structured information to help users quickly add activities to their calendar.

## Context
- Today's date: {{current_date}}
- Current season: {{current_season}}
- User's timezone: {{user_timezone}}
- User's location: {{user_location}}

## Required Output Format
Return a JSON object with these exact fields:

{
  "name": "Short activity title (2-5 words)",
  "description": "Expanded description (1-2 sentences)",
  "schedule_type": "flexible" | "scheduled" | "deadline",
  "start_time": "HH:MM" (only if schedule_type is 'scheduled'),
  "deadline": "YYYY-MM-DD" (only if schedule_type is 'deadline'),
  "suggested_months": [array of 1-12 representing best months],
  "suggested_days_of_week": [array of 1-7 where 1=Monday, 7=Sunday],
  "suggested_time_of_day": "morning" | "afternoon" | "evening" | "night" | "anytime",
  "max_frequency_days": integer (days between repetitions: 7, 14, 30, 90, 365, etc.),
  "duration_hours": decimal (estimated duration),
  "category_tags": [array of tags like "outdoor", "social", "food", "culture"],
  "location": "extracted location or null",
  "confidence": integer 0-100,
  "reasoning": {
    "time_of_year": "explanation for suggested_months",
    "day_of_week": "explanation for suggested_days_of_week",
    "time_of_day": "explanation for suggested_time_of_day",
    "frequency": "explanation for max_frequency_days",
    "schedule_type": "explanation for chosen schedule_type"
  },
  "playlist_suggestion": {
    "name": "suggested playlist name",
    "confidence": integer 0-100,
    "reasoning": "why this playlist"
  }
}

## Guidelines
1. **schedule_type**:
   - "flexible": No specific date/time mentioned, can happen anytime
   - "scheduled": Specific recurring pattern (e.g., "every Friday", "weekly")
   - "deadline": Time-sensitive or expiring (e.g., "before March", "museum closes")

2. **Time of Year**: Consider:
   - Seasonal activities (skiing → winter, beach → summer)
   - Weather dependencies (outdoor hiking → spring/summer/fall)
   - Cultural events (pumpkin picking → October)
   - Practical constraints (ice skating → winter months)

3. **Day of Week**: Consider:
   - Business hours (happy hour → weekdays)
   - Social norms (brunch → weekends)
   - Venue schedules (museums → any day)
   - User patterns (date night → Friday/Saturday)

4. **Time of Day**: Keywords like:
   - morning: breakfast, coffee, sunrise, hike
   - afternoon: lunch, matinee, shopping
   - evening: dinner, sunset, happy hour
   - night: bars, clubs, stargazing

5. **Frequency**: Consider:
   - Cost/effort (expensive → yearly, cheap → weekly)
   - Seasonality (seasonal → yearly)
   - Explicit mentions ("weekly" → 7, "monthly" → 30)
   - Activity type (habits → 7, special occasions → 365)

6. **Confidence**:
   - 90-100: Very clear, specific input
   - 70-89: Good understanding, some assumptions
   - 50-69: Moderate ambiguity, reasonable guesses
   - <50: Very vague, needs user clarification

7. **Category Tags**: Common tags:
   - outdoor, indoor
   - social, solo
   - food, drink, dining
   - culture, art, museum
   - sports, fitness, active
   - entertainment, relaxation
   - family-friendly, adults-only
   - seasonal, holiday
   - educational, professional

## Examples

Input: "Go apple picking in October"
→ flexible activity, months=[9,10], days=[6,7], time=afternoon, freq=365

Input: "Weekly happy hour on Fridays at 5pm"
→ scheduled activity, months=all, days=[5], time=evening, freq=7, start_time="17:00"

Input: "Visit museum exhibit before it closes in March"
→ deadline activity, months=[1,2,3], deadline=March 31, freq=90

Input: "Try that new Italian restaurant"
→ flexible, months=all, days=[5,6,7], time=evening, freq=60

## Important
- Always return valid JSON
- If input is ambiguous, make reasonable assumptions but lower confidence
- Provide clear reasoning for each suggestion
- Consider user's location and timezone for suggestions
- Be thoughtful about cultural context and social norms
```

---

## Appendix C: Wireframes

*[To be added: Figma designs for AI input modal, review UI, mobile views]*

---

## Appendix D: Cost-Benefit Analysis

### Benefits (Quantified)

**Time Savings:**
- Manual activity creation: ~2 minutes average
- AI-assisted creation: ~30 seconds average
- Time saved per activity: 90 seconds
- If 100 activities created per month: 150 minutes saved (2.5 hours)

**User Value:**
- Improved accuracy in scheduling (fewer conflicts)
- Better discovery of optimal timing
- Reduced cognitive load
- Higher activity completion rates (well-timed activities more likely to happen)

### Costs (Quantified)

**Development:**
- Engineering: 6 weeks × $100/hour × 40 hours = $24,000
- Design: 1 week × $100/hour × 20 hours = $2,000
- Testing: 1 week × $100/hour × 20 hours = $2,000
- **Total upfront: $28,000**

**Operating (Monthly):**
- AI API costs: $600/month (at 10K users, 10 suggestions each)
- Infrastructure: Minimal (background jobs, caching)
- **Total monthly: $600-800**

### ROI Calculation

**Assumptions:**
- 10,000 active users
- Each creates 10 activities per month = 100,000 activities
- Time saved: 90 seconds × 100,000 = 2,500 hours
- User value of time: $20/hour
- **Monthly value: $50,000**

**ROI:** ($50,000 - $800) / $800 = **6,150% monthly ROI**

**Payback period:** $28,000 / $49,200 = **0.57 months** (17 days)

---

## Appendix E: URL Extraction Examples

### Example 1: Eventbrite Event

**URL:** `https://www.eventbrite.com/e/summer-music-festival-2026-tickets`

**Extracted Schema.org JSON-LD:**
```json
{
  "@context": "https://schema.org",
  "@type": "Event",
  "name": "Summer Music Festival 2026",
  "description": "Annual outdoor music festival featuring local bands...",
  "startDate": "2026-07-15T14:00:00-07:00",
  "endDate": "2026-07-15T22:00:00-07:00",
  "location": {
    "@type": "Place",
    "name": "Golden Gate Park",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "501 Stanyan St",
      "addressLocality": "San Francisco",
      "addressRegion": "CA",
      "postalCode": "94117"
    }
  },
  "offers": {
    "@type": "Offer",
    "price": "45.00",
    "priceCurrency": "USD",
    "availability": "https://schema.org/InStock"
  },
  "organizer": {
    "@type": "Organization",
    "name": "SF Music Events"
  },
  "image": "https://img.evbuc.com/event-image.jpg"
}
```

**AI-Generated Activity Fields:**
```json
{
  "name": "Summer Music Festival 2026",
  "description": "Annual outdoor music festival featuring local bands at Golden Gate Park",
  "schedule_type": "deadline",
  "deadline": "2026-07-15",
  "start_time": "14:00",
  "end_time": "22:00",
  "location": "Golden Gate Park, San Francisco, CA",
  "suggested_months": [7],
  "suggested_days_of_week": [6],
  "suggested_time_of_day": "afternoon",
  "max_frequency_days": 365,
  "duration_hours": 8,
  "category_tags": ["music", "outdoor", "festival", "culture"],
  "price": 45.00,
  "organizer": "SF Music Events",
  "image_url": "https://img.evbuc.com/event-image.jpg",
  "source_url": "https://www.eventbrite.com/e/...",
  "confidence": 98
}
```

### Example 2: Museum Website (Unstructured)

**URL:** `https://sfmoma.org/exhibition/contemporary-art-exhibit`

**HTML Content (No Schema.org):**
```html
<h1>Contemporary Art: New Voices</h1>
<p>Running through March 31, 2026</p>
<p>Explore groundbreaking works from emerging artists...</p>
<div class="location">San Francisco Museum of Modern Art</div>
<div class="hours">Open Tuesday-Sunday, 10am-5pm</div>
```

**AI Extracts:**
```json
{
  "name": "Contemporary Art: New Voices",
  "description": "Explore groundbreaking works from emerging artists at SFMOMA",
  "schedule_type": "deadline",
  "deadline": "2026-03-31",
  "location": "San Francisco Museum of Modern Art",
  "suggested_months": [1, 2, 3],
  "suggested_days_of_week": [2, 3, 4, 5, 6, 7],
  "suggested_time_of_day": "afternoon",
  "max_frequency_days": 90,
  "duration_hours": 2,
  "category_tags": ["art", "museum", "culture", "indoor"],
  "organizer": "SFMOMA",
  "source_url": "https://sfmoma.org/exhibition/...",
  "confidence": 85,
  "reasoning": {
    "deadline": "Exhibit closes March 31, 2026 - marked as deadline activity",
    "hours": "Open Tuesday-Sunday, suggesting weekday or weekend visit",
    "duration": "Typical museum visit is 2 hours"
  }
}
```

### Example 3: Restaurant Reservation (OpenTable)

**URL:** `https://www.opentable.com/r/italian-bistro-san-francisco`

**Open Graph Meta Tags:**
```html
<meta property="og:title" content="Italian Bistro - San Francisco">
<meta property="og:description" content="Authentic Italian cuisine in the heart of North Beach">
<meta property="og:image" content="https://cdn.opentable.com/restaurant.jpg">
<meta property="restaurant:hours" content="Mon-Sun 5pm-10pm">
<meta property="restaurant:price_range" content="$$">
```

**AI Extracts:**
```json
{
  "name": "Dinner at Italian Bistro",
  "description": "Authentic Italian cuisine in the heart of North Beach, San Francisco",
  "schedule_type": "flexible",
  "location": "Italian Bistro, North Beach, San Francisco",
  "suggested_months": [1,2,3,4,5,6,7,8,9,10,11,12],
  "suggested_days_of_week": [5, 6],
  "suggested_time_of_day": "evening",
  "start_time": "19:00",
  "max_frequency_days": 30,
  "duration_hours": 2,
  "category_tags": ["dining", "italian", "social", "date_night"],
  "price": 75.00,
  "organizer": "Italian Bistro",
  "image_url": "https://cdn.opentable.com/restaurant.jpg",
  "source_url": "https://www.opentable.com/r/...",
  "confidence": 90,
  "reasoning": {
    "day_of_week": "Italian restaurant - suggested for weekend dinner/date night",
    "time_of_day": "Dinner hours 5pm-10pm, recommend 7pm reservation",
    "price": "Estimated $75 for dinner for two ($$$ rating)"
  }
}
```

### Example 4: Meetup.com Recurring Event

**URL:** `https://www.meetup.com/sf-hiking-club/events/298765432`

**Schema.org Event (Recurring):**
```json
{
  "@type": "Event",
  "name": "Saturday Morning Hikes",
  "description": "Join us for weekly hikes in the Bay Area...",
  "startDate": "2026-02-07T08:00:00",
  "endDate": "2026-02-07T12:00:00",
  "eventSchedule": {
    "@type": "Schedule",
    "repeatFrequency": "P1W",
    "byDay": "Saturday"
  },
  "location": {
    "@type": "Place",
    "name": "Varies - check event page"
  }
}
```

**AI Extracts:**
```json
{
  "name": "Saturday Morning Hikes",
  "description": "Weekly hikes in the Bay Area with SF Hiking Club. Locations vary each week.",
  "schedule_type": "scheduled",
  "start_time": "08:00",
  "end_time": "12:00",
  "suggested_months": [3, 4, 5, 6, 7, 8, 9, 10],
  "suggested_days_of_week": [6],
  "suggested_time_of_day": "morning",
  "max_frequency_days": 7,
  "duration_hours": 4,
  "category_tags": ["outdoor", "hiking", "fitness", "social", "recurring"],
  "organizer": "SF Hiking Club",
  "source_url": "https://www.meetup.com/...",
  "event_metadata": {
    "recurring": true,
    "recurrence_pattern": "weekly",
    "recurrence_day": "Saturday"
  },
  "confidence": 95,
  "reasoning": {
    "schedule_type": "Recurring weekly event - marked as scheduled",
    "time": "Consistent Saturday mornings at 8am",
    "frequency": "Weekly recurrence, max_frequency_days = 7",
    "months": "Best for spring through fall hiking season"
  }
}
```

### Example 5: Facebook Event (Public)

**URL:** `https://www.facebook.com/events/123456789`

**Open Graph + Schema.org:**
```json
{
  "@type": "Event",
  "name": "Community Potluck Dinner",
  "startDate": "2026-03-20T18:00:00",
  "location": {
    "name": "Community Center",
    "address": "123 Main St, Oakland, CA"
  }
}
```

**AI Extracts:**
```json
{
  "name": "Community Potluck Dinner",
  "description": "Monthly potluck gathering at Oakland Community Center. Bring a dish to share!",
  "schedule_type": "scheduled",
  "start_time": "18:00",
  "location": "Community Center, 123 Main St, Oakland, CA",
  "suggested_months": [1,2,3,4,5,6,7,8,9,10,11,12],
  "suggested_days_of_week": [5],
  "suggested_time_of_day": "evening",
  "max_frequency_days": 30,
  "duration_hours": 3,
  "category_tags": ["social", "community", "food", "indoor"],
  "price": 0,
  "source_url": "https://www.facebook.com/events/...",
  "confidence": 88
}
```

### URL Extraction Architecture

**Processing Pipeline:**

```ruby
class UrlActivityExtractor
  def extract(url)
    # 1. Validate and fetch URL
    html = fetch_url(url)

    # 2. Try structured data extraction first (fast path)
    if structured_data = extract_schema_org(html)
      return parse_schema_org(structured_data)
    elsif og_data = extract_open_graph(html)
      return parse_open_graph(og_data)
    end

    # 3. Fall back to AI extraction (slow path)
    ai_extract_from_html(html, url)
  end

  private

  def extract_schema_org(html)
    # Parse JSON-LD script tags
    doc = Nokogiri::HTML(html)
    doc.css('script[type="application/ld+json"]').map do |script|
      JSON.parse(script.content)
    end.find { |data| data['@type'] == 'Event' }
  rescue JSON::ParserError
    nil
  end

  def extract_open_graph(html)
    doc = Nokogiri::HTML(html)
    meta_tags = doc.css('meta[property^="og:"]')
    meta_tags.each_with_object({}) do |tag, hash|
      property = tag['property'].sub('og:', '')
      hash[property] = tag['content']
    end
  end

  def ai_extract_from_html(html, url)
    # Use AI to extract event details from unstructured HTML
    cleaned_html = extract_main_content(html)

    prompt = build_extraction_prompt(cleaned_html, url)
    ai_response = call_ai_api(prompt)

    parse_ai_response(ai_response)
  end
end
```

**Gem Requirements:**
```ruby
# Gemfile
gem 'nokogiri'          # HTML parsing
gem 'httparty'          # HTTP requests
gem 'addressable'       # URL validation
gem 'metainspector'     # Meta tag extraction (alternative)
gem 'anthropic'         # Claude API (or 'ruby-openai' for GPT)
```

### Supported Event Platforms (Priority Order)

**Tier 1: Full Support (Schema.org + API)**
- ✅ Eventbrite
- ✅ Meetup.com
- ✅ Ticketmaster

**Tier 2: Partial Support (Open Graph)**
- ⚠️ Facebook Events (public only)
- ⚠️ OpenTable/Resy
- ⚠️ Concert venue websites

**Tier 3: AI Fallback (Unstructured)**
- 🤖 Museum websites
- 🤖 Restaurant websites
- 🤖 Local event pages
- 🤖 Generic venue pages

---

*End of PRD*
