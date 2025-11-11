# Technical Implementation Plan: AI Activity Suggestions

**Document Version:** 1.0
**Status:** Draft
**Last Updated:** 2025-11-08
**Related PRD:** `prd_ai_activity_suggestions.md`
**Owner:** Engineering Team

---

## 1. Executive Summary

### Scope
Implement AI-powered activity suggestion system supporting:
1. Natural language text input → activity creation
2. URL/link extraction → structured event data
3. Smart scheduling recommendations (time of year, day, frequency)
4. Progressive disclosure review UI with UX improvements

### Timeline
- **Phase 1 (MVP)**: 6 weeks
- **Phase 2 (Enhancements)**: 4 weeks
- **Total**: 10 weeks

### Key Technical Decisions
- **AI Provider**: Anthropic Claude 3.5 Sonnet (primary)
- **URL Parsing**: Nokogiri + Schema.org extraction
- **Background Jobs**: Solid Queue (already in stack)
- **Caching**: Rails.cache (Solid Cache) + Redis for rate limiting
- **Testing**: VCR for AI API mocking, RSpec for services

---

## 2. Architecture Overview

### High-Level System Design

```
┌─────────────────────────────────────────────────────────────┐
│                         User Interface                       │
│  ┌──────────────────┐         ┌─────────────────────┐      │
│  │ Smart Input Field│────────▶│  Review/Preview UI   │      │
│  │ (Text or URL)    │         │  (Simplified Cards)  │      │
│  └──────────────────┘         └─────────────────────┘      │
└────────────┬────────────────────────────┬───────────────────┘
             │                            │
             ▼                            ▼
┌────────────────────────────────────────────────────────────┐
│                    Rails Controllers                        │
│  ┌──────────────────────────────────────────────────┐     │
│  │  AiActivitiesController                          │     │
│  │    - #new      (show input form)                 │     │
│  │    - #generate (trigger AI processing)           │     │
│  │    - #review   (show AI suggestions)             │     │
│  │    - #create   (save activity from suggestion)   │     │
│  └──────────────────────────────────────────────────┘     │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│                   Background Jobs Layer                     │
│  ┌──────────────────────────┐  ┌────────────────────────┐ │
│  │ AiSuggestionGeneratorJob │  │ UrlContentFetcherJob   │ │
│  │ - Parse text input       │  │ - Fetch URL content    │ │
│  │ - Call AI API            │  │ - Extract metadata     │ │
│  │ - Parse AI response      │  │ - Cache results        │ │
│  └──────────────────────────┘  └────────────────────────┘ │
└────────────┬──────────────────────────┬────────────────────┘
             │                          │
             ▼                          ▼
┌────────────────────────────────────────────────────────────┐
│                     Service Layer                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ AiActivityService                                   │  │
│  │  - orchestrates entire AI flow                      │  │
│  └─────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ ClaudeApiService                                    │  │
│  │  - manage API requests to Anthropic                 │  │
│  │  - handle rate limiting, retries, errors            │  │
│  └─────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ UrlExtractorService                                 │  │
│  │  - detect URL in input                              │  │
│  │  - fetch webpage content                            │  │
│  │  - extract Schema.org / OpenGraph data              │  │
│  │  - fallback to AI extraction                        │  │
│  └─────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ ActivitySchedulingAnalyzer                          │  │
│  │  - analyze activity type                            │  │
│  │  - suggest optimal timing                           │  │
│  │  - determine schedule_type                          │  │
│  └─────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ SuggestionReviewBuilder                             │  │
│  │  - format AI response for UI                        │  │
│  │  - calculate confidence scores                      │  │
│  │  - generate reasoning text                          │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────┬──────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│                      Data Layer                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Models                                              │  │
│  │  - Activity (extended with AI fields)              │  │
│  │  - AiActivitySuggestion (new)                      │  │
│  └─────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Cache Stores                                        │  │
│  │  - Rails.cache (Solid Cache)                       │  │
│  │  - Redis (rate limiting)                           │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

### Data Flow: Text Input

```
1. User enters: "Go apple picking in October"
   ↓
2. POST /ai_activities/generate
   ↓
3. AiSuggestionGeneratorJob.perform_later(user_id, input_text)
   ↓
4. Job calls: AiActivityService.generate_suggestion(input_text)
   ↓
5. Service calls: ClaudeApiService.extract_activity(input_text)
   ↓
6. AI returns structured JSON with activity details
   ↓
7. Service calls: ActivitySchedulingAnalyzer.analyze(ai_data)
   ↓
8. Analyzer enriches with scheduling metadata
   ↓
9. Save to ai_activity_suggestions table
   ↓
10. Broadcast via Turbo Stream to user's browser
   ↓
11. User sees preview card with suggestions
   ↓
12. User clicks "Add to Calendar"
   ↓
13. POST /ai_activities with suggestion_id
   ↓
14. Create Activity record, link to ai_suggestion
   ↓
15. Track user edits for learning
```

### Data Flow: URL Input

```
1. User pastes: "https://eventbrite.com/e/summer-festival"
   ↓
2. Frontend detects URL pattern (client-side)
   ↓
3. POST /ai_activities/generate with input_type: "url"
   ↓
4. UrlContentFetcherJob.perform_later(user_id, url)
   ↓
5. Job calls: UrlExtractorService.extract(url)
   ↓
6. Service fetches webpage HTML
   ↓
7. Parse Schema.org JSON-LD or OpenGraph tags
   ↓
8. If structured data found:
   └─> Parse directly to activity fields (fast path)

9. If no structured data:
   └─> Call ClaudeApiService.extract_from_html(html)
   └─> AI extracts from unstructured content (slow path)
   ↓
10. Merge structured + AI data
   ↓
11. Save to ai_activity_suggestions with source_url
   ↓
12. Broadcast to browser
   ↓
13. (Same as text flow from step 11)
```

---

## 3. Technology Stack & Dependencies

### New Gems Required

```ruby
# Gemfile

# AI API Integration
gem 'anthropic', '~> 0.3.0'         # Claude API client
# Alternative: gem 'ruby-openai' if using GPT-4

# URL Extraction & Parsing
gem 'nokogiri', '~> 1.16'           # HTML/XML parsing (already installed)
gem 'httparty', '~> 0.21'           # HTTP requests for URL fetching
gem 'addressable', '~> 2.8'         # URL validation and parsing
gem 'robots', '~> 0.10'             # robots.txt parsing

# Rate Limiting
gem 'redis', '~> 5.0'               # For rate limiting (may already be installed)
gem 'redis-namespace', '~> 1.11'    # Namespace Redis keys

# Caching & Performance
gem 'connection_pool', '~> 2.4'     # Thread-safe connection pooling

group :test do
  gem 'vcr', '~> 6.2'               # HTTP interaction recording (already installed)
  gem 'webmock', '~> 3.19'          # HTTP request stubbing (already installed)
end
```

### External Services

**Anthropic Claude API:**
- Endpoint: `https://api.anthropic.com/v1/messages`
- Authentication: API key via `ANTHROPIC_API_KEY` env var
- Model: `claude-3-5-sonnet-20241022` (latest as of Nov 2024)
- Rate limits: 50 requests/minute (Tier 1), 1000 requests/minute (Tier 2)
- Pricing: ~$0.006 per request (estimate)

**Optional: OpenAI GPT-4 (Fallback):**
- Endpoint: `https://api.openai.com/v1/chat/completions`
- Authentication: API key via `OPENAI_API_KEY` env var
- Model: `gpt-4-turbo-preview`
- Rate limits: Similar to Claude

### Infrastructure Requirements

- **Redis**: For rate limiting and fast caching (consider adding if not present)
- **Background Job Workers**: Increase Solid Queue workers by 2 for AI jobs
- **Environment Variables**:
  ```bash
  ANTHROPIC_API_KEY=sk-ant-...
  OPENAI_API_KEY=sk-...  # optional fallback
  AI_FEATURE_ENABLED=true
  AI_MONTHLY_REQUEST_LIMIT=10000
  ```

---

## 4. Database Schema Changes

### Migration 1: Create `ai_activity_suggestions` Table

```ruby
# db/migrate/20250108000001_create_ai_activity_suggestions.rb

class CreateAiActivitySuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_activity_suggestions do |t|
      # User & Input
      t.references :user, null: false, foreign_key: true, index: true
      t.string :input_type, null: false, default: 'text' # enum: text, url
      t.text :input_text # Original text input
      t.text :source_url # URL if provided

      # AI Processing
      t.string :model_used # e.g., "claude-3-5-sonnet-20241022"
      t.integer :processing_time_ms
      t.decimal :confidence_score, precision: 5, scale: 2

      # Extracted Metadata (JSONB for flexibility)
      t.jsonb :extracted_metadata, default: {} # Schema.org, OpenGraph data
      t.jsonb :api_request, default: {}        # Request sent to AI
      t.jsonb :api_response, default: {}       # Raw AI response
      t.jsonb :suggested_data, default: {}     # Structured activity data
      t.jsonb :user_edits, default: {}         # Fields user changed

      # Outcome Tracking
      t.references :final_activity, foreign_key: { to_table: :activities }, null: true
      t.boolean :accepted, default: false
      t.text :feedback # User feedback
      t.text :rejection_reason # Why user rejected

      t.timestamps
    end

    # Indexes for analytics
    add_index :ai_activity_suggestions, :input_type
    add_index :ai_activity_suggestions, :accepted
    add_index :ai_activity_suggestions, :created_at
    add_index :ai_activity_suggestions, [:user_id, :created_at]
    add_index :ai_activity_suggestions, :model_used

    # GIN index for JSONB queries (PostgreSQL)
    add_index :ai_activity_suggestions, :suggested_data, using: :gin
    add_index :ai_activity_suggestions, :extracted_metadata, using: :gin
  end
end
```

**Estimated Table Size:**
- 1,000 users × 10 suggestions/month = 10,000 rows/month
- ~120,000 rows/year
- With JSONB data: ~50-100KB per row
- Annual storage: ~6-12 GB (manageable)

### Migration 2: Extend `activities` Table

```ruby
# db/migrate/20250108000002_add_ai_fields_to_activities.rb

class AddAiFieldsToActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :activities, :ai_generated, :boolean, default: false, null: false
    add_reference :activities, :ai_suggestion, foreign_key: { to_table: :ai_activity_suggestions }

    # Event/URL Source Data
    add_column :activities, :source_url, :text
    add_column :activities, :image_url, :text
    add_column :activities, :price, :decimal, precision: 10, scale: 2
    add_column :activities, :organizer, :string

    # AI Scheduling Suggestions
    add_column :activities, :suggested_months, :integer, array: true, default: []
    add_column :activities, :suggested_days_of_week, :integer, array: true, default: []
    add_column :activities, :suggested_time_of_day, :string # enum: morning, afternoon, evening, night, anytime
    add_column :activities, :category_tags, :string, array: true, default: []

    # Additional Event Metadata
    add_column :activities, :event_metadata, :jsonb, default: {}

    # Indexes
    add_index :activities, :ai_generated
    add_index :activities, :suggested_months, using: :gin
    add_index :activities, :suggested_days_of_week, using: :gin
    add_index :activities, :category_tags, using: :gin
    add_index :activities, :event_metadata, using: :gin
  end
end
```

### Model Definitions

```ruby
# app/models/ai_activity_suggestion.rb

class AiActivitySuggestion < ApplicationRecord
  belongs_to :user
  belongs_to :final_activity, class_name: 'Activity', optional: true

  # Enums
  enum input_type: { text: 'text', url: 'url' }

  # Validations
  validates :input_type, presence: true
  validates :input_text, presence: true, if: -> { text? }
  validates :source_url, presence: true, format: URI::regexp(%w[http https]), if: -> { url? }
  validates :model_used, presence: true
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  # Scopes
  scope :accepted, -> { where(accepted: true) }
  scope :rejected, -> { where(accepted: false).where.not(rejection_reason: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :text_inputs, -> { where(input_type: 'text') }
  scope :url_inputs, -> { where(input_type: 'url') }

  # Callbacks
  before_validation :normalize_url, if: -> { url? }

  # Methods
  def accept!(activity)
    update!(
      accepted: true,
      final_activity: activity
    )
  end

  def reject!(reason)
    update!(
      accepted: false,
      rejection_reason: reason
    )
  end

  def edit_distance
    return {} if user_edits.blank?

    # Calculate which fields were edited
    user_edits.transform_values do |edit|
      {
        original: edit['original'],
        final: edit['final'],
        changed: edit['original'] != edit['final']
      }
    end
  end

  private

  def normalize_url
    self.source_url = Addressable::URI.parse(source_url).normalize.to_s
  rescue Addressable::URI::InvalidURIError
    errors.add(:source_url, 'is not a valid URL')
  end
end
```

```ruby
# app/models/activity.rb (additions)

class Activity < ApplicationRecord
  # ... existing code ...

  belongs_to :ai_suggestion, class_name: 'AiActivitySuggestion', optional: true

  # Enums for suggested_time_of_day
  enum suggested_time_of_day: {
    morning: 'morning',
    afternoon: 'afternoon',
    evening: 'evening',
    night: 'night',
    anytime: 'anytime'
  }, _prefix: true

  # Scopes
  scope :ai_generated, -> { where(ai_generated: true) }
  scope :manual, -> { where(ai_generated: false) }
  scope :with_source_url, -> { where.not(source_url: nil) }
  scope :by_month, ->(month) { where('? = ANY(suggested_months)', month) }
  scope :by_day_of_week, ->(day) { where('? = ANY(suggested_days_of_week)', day) }
  scope :by_tag, ->(tag) { where('? = ANY(category_tags)', tag) }

  # Validations
  validates :suggested_time_of_day, inclusion: { in: suggested_time_of_days.keys }, allow_nil: true
  validates :suggested_months, inclusion: { in: (1..12).to_a }, allow_nil: true
  validates :suggested_days_of_week, inclusion: { in: (1..7).to_a }, allow_nil: true

  # Methods
  def from_ai?
    ai_generated?
  end

  def best_months_names
    return [] if suggested_months.blank?
    suggested_months.map { |m| Date::MONTHNAMES[m] }
  end

  def best_days_names
    return [] if suggested_days_of_week.blank?
    suggested_days_of_week.map { |d| Date::DAYNAMES[d % 7] }
  end
end
```

---

## 5. Service Layer Implementation

### 5.1 Main Orchestration Service

```ruby
# app/services/ai_activity_service.rb

class AiActivityService
  class Error < StandardError; end
  class UrlFetchError < Error; end
  class AiApiError < Error; end
  class ExtractionError < Error; end

  attr_reader :user, :input, :input_type

  def initialize(user:, input:)
    @user = user
    @input = input.strip
    @input_type = detect_input_type
  end

  def generate_suggestion
    # Check rate limits
    check_rate_limits!

    # Process based on input type
    case input_type
    when :url
      generate_from_url
    when :text
      generate_from_text
    else
      raise Error, "Unknown input type: #{input_type}"
    end
  rescue StandardError => e
    handle_error(e)
  end

  private

  def detect_input_type
    # Simple URL detection
    if input.match?(%r{\Ahttps?://}i)
      :url
    else
      :text
    end
  end

  def generate_from_text
    start_time = Time.current

    # Call AI to extract activity details
    ai_response = ClaudeApiService.new.extract_activity(input)

    # Analyze scheduling
    scheduling = ActivitySchedulingAnalyzer.new(ai_response).analyze

    # Merge AI response with scheduling analysis
    suggested_data = ai_response.merge(scheduling)

    # Create suggestion record
    suggestion = AiActivitySuggestion.create!(
      user: user,
      input_type: 'text',
      input_text: input,
      model_used: 'claude-3-5-sonnet-20241022',
      processing_time_ms: ((Time.current - start_time) * 1000).to_i,
      confidence_score: calculate_confidence(suggested_data),
      api_response: ai_response,
      suggested_data: suggested_data
    )

    # Track usage for analytics
    track_ai_usage(suggestion)

    suggestion
  end

  def generate_from_url
    start_time = Time.current

    # Extract from URL
    extractor = UrlExtractorService.new(input)
    extraction_result = extractor.extract

    # Determine if we need AI augmentation
    if extraction_result[:needs_ai_parsing]
      ai_response = ClaudeApiService.new.extract_from_html(
        extraction_result[:html_content],
        input
      )
      suggested_data = extraction_result[:structured_data].merge(ai_response)
    else
      suggested_data = extraction_result[:structured_data]
    end

    # Analyze scheduling
    scheduling = ActivitySchedulingAnalyzer.new(suggested_data).analyze
    suggested_data.merge!(scheduling)

    # Create suggestion record
    suggestion = AiActivitySuggestion.create!(
      user: user,
      input_type: 'url',
      source_url: input,
      model_used: extraction_result[:needs_ai_parsing] ? 'claude-3-5-sonnet-20241022' : 'schema_org',
      processing_time_ms: ((Time.current - start_time) * 1000).to_i,
      confidence_score: calculate_confidence(suggested_data),
      extracted_metadata: extraction_result[:structured_data],
      api_response: extraction_result[:needs_ai_parsing] ? ai_response : {},
      suggested_data: suggested_data
    )

    track_ai_usage(suggestion)

    suggestion
  end

  def check_rate_limits!
    # User rate limit: 10 requests per minute
    user_key = "ai_suggestions:rate_limit:user:#{user.id}"
    user_count = Rails.cache.read(user_key) || 0

    if user_count >= 10
      raise Error, "Rate limit exceeded. Please wait a minute and try again."
    end

    Rails.cache.write(user_key, user_count + 1, expires_in: 1.minute)

    # Global rate limit: Check monthly quota
    monthly_key = "ai_suggestions:monthly_count:#{Date.current.strftime('%Y-%m')}"
    monthly_count = Rails.cache.read(monthly_key) || 0
    monthly_limit = ENV.fetch('AI_MONTHLY_REQUEST_LIMIT', 10_000).to_i

    if monthly_count >= monthly_limit
      raise Error, "Monthly AI request limit reached. Please contact support."
    end
  end

  def calculate_confidence(suggested_data)
    # Simple confidence calculation based on data completeness
    required_fields = %w[name description schedule_type]
    optional_fields = %w[location duration_hours suggested_months suggested_days_of_week]

    required_present = required_fields.count { |f| suggested_data[f].present? }
    optional_present = optional_fields.count { |f| suggested_data[f].present? }

    base_confidence = (required_present.to_f / required_fields.size) * 70
    bonus_confidence = (optional_present.to_f / optional_fields.size) * 30

    (base_confidence + bonus_confidence).round(2)
  end

  def track_ai_usage(suggestion)
    # Increment monthly counter
    monthly_key = "ai_suggestions:monthly_count:#{Date.current.strftime('%Y-%m')}"
    monthly_count = Rails.cache.read(monthly_key) || 0
    Rails.cache.write(monthly_key, monthly_count + 1, expires_in: 60.days)

    # Log to analytics (if using a service like Mixpanel, Amplitude, etc.)
    # Analytics.track(
    #   user_id: user.id,
    #   event: 'ai_suggestion_generated',
    #   properties: {
    #     input_type: suggestion.input_type,
    #     confidence: suggestion.confidence_score,
    #     processing_time_ms: suggestion.processing_time_ms,
    #     model: suggestion.model_used
    #   }
    # )
  end

  def handle_error(error)
    # Log error for monitoring
    Rails.logger.error("AI Suggestion Error: #{error.class} - #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))

    # Return user-friendly error
    {
      error: true,
      message: error_message_for(error),
      original_error: error.class.name
    }
  end

  def error_message_for(error)
    case error
    when UrlFetchError
      "We couldn't access that URL. The page might be private or temporarily unavailable."
    when AiApiError
      "AI service is temporarily unavailable. Please try again in a few moments."
    when Anthropic::Error
      "There was an issue with the AI service. Please try again."
    else
      "Something went wrong. Please try again or use the manual form."
    end
  end
end
```

### 5.2 Claude API Service

```ruby
# app/services/claude_api_service.rb

class ClaudeApiService
  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an intelligent activity planning assistant for Sidewalks, an app that helps users organize activities.

    Your task is to extract structured information from natural language descriptions of activities
    and suggest optimal scheduling parameters.

    Current date: {{current_date}}
    Current season: {{current_season}}

    Return a JSON object with these exact fields:
    {
      "name": "Short activity title (2-5 words)",
      "description": "Expanded description (1-2 sentences)",
      "schedule_type": "flexible" | "scheduled" | "deadline",
      "start_time": "HH:MM" (only if scheduled),
      "end_time": "HH:MM" (if known),
      "deadline": "YYYY-MM-DD" (only if deadline type),
      "suggested_months": [array of 1-12],
      "suggested_days_of_week": [array of 1-7 where 1=Monday],
      "suggested_time_of_day": "morning" | "afternoon" | "evening" | "night" | "anytime",
      "max_frequency_days": integer (7, 30, 90, 365, etc.),
      "duration_hours": decimal,
      "category_tags": [array of tags],
      "location": "extracted location or null"
    }

    Always return valid JSON. Be concise and accurate.
  PROMPT

  def initialize
    @client = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
  end

  def extract_activity(user_input)
    prompt = SYSTEM_PROMPT
      .gsub('{{current_date}}', Date.current.to_s)
      .gsub('{{current_season}}', current_season)

    response = with_retry do
      @client.messages(
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 1024,
        messages: [
          { role: 'user', content: "Activity description: #{user_input}" }
        ],
        system: prompt
      )
    end

    extract_json_from_response(response)
  rescue Anthropic::Error => e
    Rails.logger.error("Claude API Error: #{e.message}")
    raise AiActivityService::AiApiError, e.message
  end

  def extract_from_html(html_content, url)
    # Simplified HTML for AI parsing (remove scripts, styles, etc.)
    cleaned_html = clean_html(html_content)

    prompt = <<~PROMPT
      Extract event/activity details from this webpage HTML.

      URL: #{url}

      HTML Content:
      #{cleaned_html[0..5000]} # Limit to prevent token overflow

      Return JSON in the same format as before.
    PROMPT

    response = with_retry do
      @client.messages(
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 1024,
        messages: [{ role: 'user', content: prompt }],
        system: SYSTEM_PROMPT
      )
    end

    extract_json_from_response(response)
  end

  private

  def current_season
    month = Date.current.month
    case month
    when 12, 1, 2 then 'Winter'
    when 3, 4, 5 then 'Spring'
    when 6, 7, 8 then 'Summer'
    when 9, 10, 11 then 'Fall'
    end
  end

  def with_retry(max_retries: 3, &block)
    retries = 0
    begin
      yield
    rescue Anthropic::Error => e
      retries += 1
      if retries < max_retries && retriable_error?(e)
        sleep(2**retries) # Exponential backoff
        retry
      else
        raise
      end
    end
  end

  def retriable_error?(error)
    # Retry on rate limits and server errors, not on auth/validation errors
    error.is_a?(Anthropic::RateLimitError) ||
    error.is_a?(Anthropic::ServerError)
  end

  def extract_json_from_response(response)
    content = response.dig('content', 0, 'text')

    # Claude sometimes wraps JSON in markdown code blocks
    json_match = content.match(/```json\s*(\{.*?\})\s*```/m) ||
                 content.match(/(\{.*\})/m)

    json_string = json_match ? json_match[1] : content

    JSON.parse(json_string)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse AI response as JSON: #{content}")
    raise AiActivityService::ExtractionError, "AI returned invalid JSON: #{e.message}"
  end

  def clean_html(html)
    doc = Nokogiri::HTML(html)

    # Remove scripts, styles, nav, footer
    doc.css('script, style, nav, footer, header, iframe').remove

    # Extract main content
    main = doc.at_css('main, article, [role="main"], .content, #content') || doc.at_css('body')

    # Get text with some structure preserved
    main&.text&.gsub(/\s+/, ' ')&.strip || ''
  end
end
```

### 5.3 URL Extractor Service

```ruby
# app/services/url_extractor_service.rb

class UrlExtractorService
  TIMEOUT_SECONDS = 10
  USER_AGENT = "Sidewalks Activity Bot/1.0 (+https://sidewalks.app/bot; contact@sidewalks.app)"

  def initialize(url)
    @url = normalize_url(url)
  end

  def extract
    # Check cache first
    cache_key = "url_extraction:#{Digest::MD5.hexdigest(@url)}"
    cached = Rails.cache.read(cache_key)
    return cached if cached.present?

    # Validate URL
    validate_url!

    # Check robots.txt
    check_robots_txt!

    # Fetch content
    html = fetch_url_content

    # Try structured data extraction first (fast path)
    structured_data = extract_structured_data(html)

    result = if structured_data.present? && sufficient_data?(structured_data)
      {
        structured_data: structured_data,
        html_content: nil,
        needs_ai_parsing: false
      }
    else
      # Fall back to AI parsing (slow path)
      {
        structured_data: structured_data || {},
        html_content: html,
        needs_ai_parsing: true
      }
    end

    # Cache for 24 hours
    Rails.cache.write(cache_key, result, expires_in: 24.hours)

    result
  rescue StandardError => e
    Rails.logger.error("URL Extraction Error (#{@url}): #{e.message}")
    raise AiActivityService::UrlFetchError, e.message
  end

  private

  def normalize_url(url)
    Addressable::URI.parse(url).normalize.to_s
  rescue Addressable::URI::InvalidURIError => e
    raise AiActivityService::UrlFetchError, "Invalid URL: #{e.message}"
  end

  def validate_url!
    uri = URI.parse(@url)

    # Security: Block internal/localhost URLs (SSRF prevention)
    if uri.host.nil? ||
       uri.host.match?(/^(localhost|127\.0\.0\.1|0\.0\.0\.0|10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)/)
      raise AiActivityService::UrlFetchError, "Invalid or unsafe URL"
    end

    # Only allow HTTP/HTTPS
    unless uri.scheme.match?(/^https?$/)
      raise AiActivityService::UrlFetchError, "Only HTTP(S) URLs are supported"
    end
  end

  def check_robots_txt!
    # Simple robots.txt check
    # In production, consider using 'robots' gem for full compliance
    robots_url = "#{URI.parse(@url).origin}/robots.txt"

    begin
      response = HTTP.timeout(2).get(robots_url)
      if response.status.success? && response.body.to_s.match?(/User-agent: \*/i)
        # Parse disallow rules (simplified)
        disallowed = response.body.to_s.scan(/Disallow: (.+)/i).flatten
        path = URI.parse(@url).path

        if disallowed.any? { |rule| path.start_with?(rule.strip) }
          raise AiActivityService::UrlFetchError, "URL is disallowed by robots.txt"
        end
      end
    rescue HTTP::Error
      # If robots.txt doesn't exist or times out, proceed
      Rails.logger.info("Could not fetch robots.txt for #{@url}")
    end
  end

  def fetch_url_content
    response = HTTParty.get(
      @url,
      timeout: TIMEOUT_SECONDS,
      headers: {
        'User-Agent' => USER_AGENT,
        'Accept' => 'text/html,application/xhtml+xml'
      },
      follow_redirects: true,
      max_redirects: 3
    )

    unless response.success?
      raise AiActivityService::UrlFetchError, "HTTP #{response.code}: #{response.message}"
    end

    response.body
  rescue HTTParty::Error, Timeout::Error => e
    raise AiActivityService::UrlFetchError, "Failed to fetch URL: #{e.message}"
  end

  def extract_structured_data(html)
    doc = Nokogiri::HTML(html)

    # Try Schema.org JSON-LD first (most reliable)
    schema_data = extract_schema_org(doc)
    return schema_data if schema_data.present?

    # Fall back to Open Graph
    og_data = extract_open_graph(doc)
    return og_data if og_data.present?

    # Last resort: Twitter Cards
    extract_twitter_cards(doc)
  end

  def extract_schema_org(doc)
    scripts = doc.css('script[type="application/ld+json"]')

    scripts.each do |script|
      begin
        data = JSON.parse(script.content)

        # Handle @graph format
        events = if data['@graph']
          data['@graph'].select { |item| item['@type'] == 'Event' }
        elsif data['@type'] == 'Event'
          [data]
        else
          []
        end

        return parse_schema_org_event(events.first) if events.any?
      rescue JSON::ParserError
        next
      end
    end

    nil
  end

  def parse_schema_org_event(event)
    {
      name: event['name'],
      description: event['description'],
      start_date: event['startDate'],
      end_date: event['endDate'],
      location: parse_location(event['location']),
      price: parse_price(event['offers']),
      organizer: event.dig('organizer', 'name'),
      image_url: event['image']
    }.compact
  end

  def extract_open_graph(doc)
    og = {}
    doc.css('meta[property^="og:"]').each do |meta|
      property = meta['property'].sub('og:', '')
      og[property] = meta['content']
    end

    return nil if og.empty?

    {
      name: og['title'],
      description: og['description'],
      image_url: og['image'],
      location: og['site_name'] # Approximation
    }.compact
  end

  def extract_twitter_cards(doc)
    twitter = {}
    doc.css('meta[name^="twitter:"]').each do |meta|
      property = meta['name'].sub('twitter:', '')
      twitter[property] = meta['content']
    end

    return nil if twitter.empty?

    {
      name: twitter['title'],
      description: twitter['description'],
      image_url: twitter['image']
    }.compact
  end

  def parse_location(location_data)
    return nil unless location_data

    if location_data.is_a?(Hash)
      address = location_data['address']
      if address.is_a?(Hash)
        [
          address['streetAddress'],
          address['addressLocality'],
          address['addressRegion'],
          address['postalCode']
        ].compact.join(', ')
      else
        location_data['name']
      end
    else
      location_data.to_s
    end
  end

  def parse_price(offers_data)
    return nil unless offers_data

    if offers_data.is_a?(Hash)
      offers_data['price']
    elsif offers_data.is_a?(Array)
      offers_data.first&.dig('price')
    end
  end

  def sufficient_data?(data)
    # Check if we have enough data to skip AI parsing
    required_fields = %i[name description]
    required_fields.all? { |field| data[field].present? }
  end
end
```

---

## 6. Background Jobs

### Job 1: AI Suggestion Generator

```ruby
# app/jobs/ai_suggestion_generator_job.rb

class AiSuggestionGeneratorJob < ApplicationJob
  queue_as :ai_processing

  retry_on AiActivityService::AiApiError, wait: :exponentially_longer, attempts: 3
  discard_on AiActivityService::Error

  def perform(user_id, input, request_id: nil)
    user = User.find(user_id)

    service = AiActivityService.new(user: user, input: input)
    suggestion = service.generate_suggestion

    # Broadcast result to user via Turbo Stream
    broadcast_suggestion(user, suggestion, request_id)
  rescue StandardError => e
    # Broadcast error to user
    broadcast_error(user, e, request_id)
    raise
  end

  private

  def broadcast_suggestion(user, suggestion, request_id)
    Turbo::StreamsChannel.broadcast_replace_to(
      "ai_suggestions_#{user.id}",
      target: "ai_suggestion_#{request_id}",
      partial: 'ai_activities/suggestion_card',
      locals: { suggestion: suggestion }
    )
  end

  def broadcast_error(user, error, request_id)
    Turbo::StreamsChannel.broadcast_replace_to(
      "ai_suggestions_#{user.id}",
      target: "ai_suggestion_#{request_id}",
      partial: 'ai_activities/error_message',
      locals: { error: error }
    )
  end
end
```

---

## 7. Controller Implementation

### Routes Configuration

```ruby
# config/routes.rb

Rails.application.routes.draw do
  # ... existing routes ...

  # AI Activity Suggestions
  namespace :ai do
    resources :activities, only: [:new, :create] do
      collection do
        post :generate  # Trigger AI processing
        get :status     # Check processing status (polling endpoint)
      end

      member do
        post :accept    # Accept suggestion and create activity
        post :reject    # Reject suggestion
        patch :feedback # Submit feedback
      end
    end
  end

  # OR simpler routing structure:
  resources :ai_activities, only: [:new, :create] do
    collection do
      post :generate
    end
  end
end
```

### Primary Controller

```ruby
# app/controllers/ai_activities_controller.rb

class AiActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :check_ai_feature_enabled
  before_action :set_suggestion, only: [:accept, :reject, :feedback]

  # GET /ai_activities/new
  # Shows the AI input form (simplified single-field interface)
  def new
    @request_id = SecureRandom.uuid
  end

  # POST /ai_activities/generate
  # Triggers AI processing in background
  def generate
    input = params[:input]&.strip
    request_id = params[:request_id] || SecureRandom.uuid

    # Validation
    if input.blank?
      return render json: {
        error: true,
        message: "Please enter an activity description or URL"
      }, status: :unprocessable_entity
    end

    if input.length < 5
      return render json: {
        error: true,
        message: "Please provide more details (at least 5 characters)"
      }, status: :unprocessable_entity
    end

    if input.length > 500
      return render json: {
        error: true,
        message: "Input too long (max 500 characters)"
      }, status: :unprocessable_entity
    end

    # Enqueue background job
    AiSuggestionGeneratorJob.perform_later(
      current_user.id,
      input,
      request_id: request_id
    )

    # Return immediately with request_id for tracking
    render json: {
      request_id: request_id,
      status: 'processing',
      message: 'Generating suggestions...'
    }
  end

  # POST /ai_activities/:id/accept
  # Create activity from accepted suggestion
  def accept
    user_edits = params[:edits] || {}

    # Merge AI suggestion with user edits
    activity_params = build_activity_params(@suggestion, user_edits)

    @activity = current_user.activities.build(activity_params)
    @activity.ai_generated = true
    @activity.ai_suggestion = @suggestion

    if @activity.save
      # Mark suggestion as accepted
      @suggestion.accept!(@activity)

      # Track edits for learning
      track_user_edits(@suggestion, user_edits) if user_edits.present?

      respond_to do |format|
        format.html { redirect_to @activity, notice: 'Activity created successfully!' }
        format.json { render json: { activity: @activity, redirect_url: activity_path(@activity) } }
      end
    else
      respond_to do |format|
        format.html { render :review, status: :unprocessable_entity }
        format.json { render json: { errors: @activity.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # POST /ai_activities/:id/reject
  # Reject AI suggestion
  def reject
    reason = params[:reason] || 'User dismissed'

    @suggestion.reject!(reason)

    respond_to do |format|
      format.html { redirect_to new_ai_activity_path, notice: 'Suggestion dismissed' }
      format.json { render json: { status: 'rejected' } }
    end
  end

  # PATCH /ai_activities/:id/feedback
  # Submit feedback on suggestion quality
  def feedback
    feedback_text = params[:feedback]

    @suggestion.update(feedback: feedback_text)

    render json: { status: 'success', message: 'Thanks for your feedback!' }
  end

  private

  def check_ai_feature_enabled
    unless ENV.fetch('AI_FEATURE_ENABLED', 'false') == 'true'
      redirect_to activities_path, alert: 'AI features are currently disabled'
    end
  end

  def set_suggestion
    @suggestion = current_user.ai_activity_suggestions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to ai_activities_path, alert: 'Suggestion not found' }
      format.json { render json: { error: 'Not found' }, status: :not_found }
    end
  end

  def build_activity_params(suggestion, user_edits)
    # Start with AI suggested data
    suggested = suggestion.suggested_data.with_indifferent_access

    # Apply user edits
    suggested.merge!(user_edits.with_indifferent_access)

    # Map to Activity attributes
    {
      name: suggested[:name],
      description: suggested[:description],
      location: suggested[:location],
      schedule_type: suggested[:schedule_type],
      start_time: parse_time(suggested[:start_time]),
      end_time: parse_time(suggested[:end_time]),
      deadline: parse_date(suggested[:deadline]),
      max_frequency_days: suggested[:max_frequency_days],
      suggested_months: suggested[:suggested_months],
      suggested_days_of_week: suggested[:suggested_days_of_week],
      suggested_time_of_day: suggested[:suggested_time_of_day],
      category_tags: suggested[:category_tags],
      source_url: suggestion.source_url,
      image_url: suggested[:image_url],
      price: suggested[:price],
      organizer: suggested[:organizer],
      event_metadata: suggested[:event_metadata] || {}
    }.compact
  end

  def track_user_edits(suggestion, edits)
    # Store what user changed
    original = suggestion.suggested_data
    changes = {}

    edits.each do |key, value|
      if original[key] != value
        changes[key] = {
          original: original[key],
          final: value
        }
      end
    end

    suggestion.update(user_edits: changes)

    # Trigger learning (async)
    # AiPatternLearnerJob.perform_later(current_user.id, suggestion.id)
  end

  def parse_time(time_string)
    return nil if time_string.blank?
    Time.zone.parse(time_string)
  rescue ArgumentError
    nil
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    Date.parse(date_string)
  rescue ArgumentError
    nil
  end
end
```

---

## 8. View Layer & Stimulus Controllers

### 8.1 Main Input View (Simplified UX)

```erb
<!-- app/views/ai_activities/new.html.erb -->

<div class="max-w-2xl mx-auto py-8 px-4">
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900 mb-2">Add Activity</h1>
    <p class="text-gray-600">Describe any activity or paste an event link</p>
  </div>

  <!-- Single Smart Input (UX improvement from review) -->
  <div data-controller="ai-input"
       data-ai-input-request-id-value="<%= @request_id %>"
       data-ai-input-user-id-value="<%= current_user.id %>">

    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <!-- Input Field -->
      <div class="mb-4">
        <label for="activity-input" class="sr-only">Activity description or URL</label>
        <textarea
          id="activity-input"
          data-ai-input-target="input"
          data-action="input->ai-input#detectInputType keydown.meta+enter->ai-input#submit keydown.ctrl+enter->ai-input#submit"
          class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
          rows="3"
          placeholder="What do you want to do?&#10;&#10;Try: &quot;Go apple picking in October&quot; or paste any event link..."
          maxlength="500"
        ></textarea>

        <!-- Character Counter -->
        <div class="flex justify-between items-center mt-2 text-sm text-gray-500">
          <span data-ai-input-target="inputTypeIndicator" class="flex items-center gap-1">
            <!-- Dynamically updated: "✍️ Text" or "🔗 URL detected" -->
          </span>
          <span data-ai-input-target="charCount">0 / 500</span>
        </div>
      </div>

      <!-- Examples -->
      <details class="mb-4">
        <summary class="text-sm text-gray-600 cursor-pointer hover:text-gray-900">
          💡 See examples
        </summary>
        <div class="mt-2 space-y-1 text-sm text-gray-600 pl-4">
          <p>• "Go apple picking in October"</p>
          <p>• "Weekly team standup every Monday 10am"</p>
          <p>• "https://eventbrite.com/e/summer-festival"</p>
          <p>• "Try that new Italian restaurant on Main St"</p>
        </div>
      </details>

      <!-- Submit Button -->
      <div class="flex gap-3">
        <button
          type="button"
          data-action="click->ai-input#submit"
          data-ai-input-target="submitButton"
          class="flex-1 bg-blue-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <span data-ai-input-target="submitText">Generate Activity</span>
        </button>

        <%= link_to "Use manual form",
          new_activity_path,
          class: "px-6 py-3 border border-gray-300 rounded-lg font-medium text-gray-700 hover:bg-gray-50 transition" %>
      </div>
    </div>

    <!-- Loading State -->
    <div data-ai-input-target="loadingState" class="hidden mt-6">
      <%= render 'ai_activities/loading_state' %>
    </div>

    <!-- Suggestion Result -->
    <div data-ai-input-target="suggestionResult" class="mt-6">
      <!-- Dynamically filled via Turbo Stream -->
    </div>

    <!-- Error State -->
    <div data-ai-input-target="errorState" class="hidden mt-6">
      <%= render 'ai_activities/error_state' %>
    </div>
  </div>
</div>

<%= turbo_stream_from "ai_suggestions_#{current_user.id}" %>
```

### 8.2 Suggestion Card Partial (Simplified UX)

```erb
<!-- app/views/ai_activities/_suggestion_card.html.erb -->

<div class="bg-white rounded-lg shadow-md border border-gray-200 overflow-hidden"
     data-controller="suggestion-card"
     data-suggestion-id="<%= suggestion.id %>">

  <!-- Card Header with Image (if available) -->
  <% if suggestion.suggested_data['image_url'].present? %>
    <div class="h-48 bg-gray-200">
      <%= image_tag suggestion.suggested_data['image_url'],
        class: "w-full h-full object-cover",
        alt: suggestion.suggested_data['name'] %>
    </div>
  <% end %>

  <!-- Card Body -->
  <div class="p-6">
    <!-- Activity Name -->
    <h2 class="text-2xl font-bold text-gray-900 mb-3 flex items-start gap-2">
      <%= suggestion.suggested_data['name'] %>
      <span class="text-base">✨</span>
    </h2>

    <!-- Quick Info Tags -->
    <div class="flex flex-wrap gap-2 mb-4">
      <% if suggestion.suggested_data['suggested_months'].present? %>
        <span class="inline-flex items-center gap-1 px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm">
          🗓️ <%= format_months(suggestion.suggested_data['suggested_months']) %>
        </span>
      <% end %>

      <% if suggestion.suggested_data['suggested_days_of_week'].present? %>
        <span class="inline-flex items-center gap-1 px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm">
          📅 <%= format_days_of_week(suggestion.suggested_data['suggested_days_of_week']) %>
        </span>
      <% end %>

      <% if suggestion.suggested_data['suggested_time_of_day'].present? %>
        <span class="inline-flex items-center gap-1 px-3 py-1 bg-purple-100 text-purple-700 rounded-full text-sm">
          🕐 <%= suggestion.suggested_data['suggested_time_of_day'].titleize %>
        </span>
      <% end %>

      <% if suggestion.suggested_data['price'].present? %>
        <span class="inline-flex items-center gap-1 px-3 py-1 bg-yellow-100 text-yellow-700 rounded-full text-sm">
          💵 $<%= suggestion.suggested_data['price'] %>
        </span>
      <% end %>
    </div>

    <!-- Description -->
    <p class="text-gray-700 mb-4">
      <%= suggestion.suggested_data['description'] %>
    </p>

    <!-- Location -->
    <% if suggestion.suggested_data['location'].present? %>
      <p class="text-sm text-gray-600 mb-4 flex items-center gap-1">
        <span>📍</span>
        <%= suggestion.suggested_data['location'] %>
      </p>
    <% end %>

    <!-- Source URL -->
    <% if suggestion.source_url.present? %>
      <p class="text-sm text-gray-500 mb-4 flex items-center gap-1">
        <span>🔗</span>
        <%= link_to "View event page", suggestion.source_url,
          target: "_blank",
          rel: "noopener noreferrer",
          class: "text-blue-600 hover:underline" %>
      </p>
    <% end %>

    <!-- Suggested Playlist -->
    <% if suggestion.suggested_data.dig('playlist_suggestion', 'name').present? %>
      <p class="text-sm text-gray-600 mb-4 flex items-center gap-1">
        <span>📂</span>
        Suggested for: <strong><%= suggestion.suggested_data.dig('playlist_suggestion', 'name') %></strong>
      </p>
    <% end %>

    <!-- Action Buttons -->
    <div class="flex gap-3 mt-6">
      <%= button_to "Add to Calendar",
        accept_ai_activity_path(suggestion),
        method: :post,
        class: "flex-1 bg-blue-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 transition",
        data: { turbo: false } %>

      <button
        type="button"
        data-action="click->suggestion-card#showCustomize"
        class="px-6 py-3 border border-gray-300 rounded-lg font-medium text-gray-700 hover:bg-gray-50 transition">
        ✏️ Customize
      </button>

      <%= button_to "Dismiss",
        reject_ai_activity_path(suggestion),
        method: :post,
        class: "px-4 py-3 border border-gray-300 rounded-lg font-medium text-gray-500 hover:bg-gray-50 transition",
        data: { turbo: false, confirm: "Dismiss this suggestion?" } %>
    </div>

    <!-- Expandable: Why these suggestions? -->
    <details class="mt-4">
      <summary class="text-sm text-gray-600 cursor-pointer hover:text-gray-900 flex items-center gap-1">
        <span>⌄</span>
        Why these suggestions?
        <% if suggestion.confidence_score %>
          <span class="ml-auto text-xs bg-gray-100 px-2 py-1 rounded">
            <%= confidence_label(suggestion.confidence_score) %>
          </span>
        <% end %>
      </summary>
      <div class="mt-3 space-y-2 text-sm text-gray-600 bg-gray-50 p-4 rounded-lg">
        <% if suggestion.suggested_data.dig('reasoning', 'time_of_year').present? %>
          <p><strong>Time of year:</strong> <%= suggestion.suggested_data.dig('reasoning', 'time_of_year') %></p>
        <% end %>
        <% if suggestion.suggested_data.dig('reasoning', 'day_of_week').present? %>
          <p><strong>Day of week:</strong> <%= suggestion.suggested_data.dig('reasoning', 'day_of_week') %></p>
        <% end %>
        <% if suggestion.suggested_data.dig('reasoning', 'time_of_day').present? %>
          <p><strong>Time of day:</strong> <%= suggestion.suggested_data.dig('reasoning', 'time_of_day') %></p>
        <% end %>
      </div>
    </details>
  </div>

  <!-- Customize Panel (Hidden by default) -->
  <div data-suggestion-card-target="customizePanel" class="hidden border-t border-gray-200 bg-gray-50 p-6">
    <%= render 'ai_activities/customize_form', suggestion: suggestion %>
  </div>
</div>
```

### 8.3 Stimulus Controller for Smart Input

```javascript
// app/javascript/controllers/ai_input_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input",
    "submitButton",
    "submitText",
    "charCount",
    "inputTypeIndicator",
    "loadingState",
    "suggestionResult",
    "errorState"
  ]

  static values = {
    requestId: String,
    userId: String
  }

  connect() {
    this.updateCharCount()
    this.detectInputType()
  }

  detectInputType() {
    const input = this.inputTarget.value.trim()

    // Detect if input is a URL
    const urlPattern = /^https?:\/\//i
    const isUrl = urlPattern.test(input)

    if (isUrl) {
      this.inputTypeIndicatorTarget.innerHTML = '🔗 <span class="text-blue-600">URL detected</span>'
    } else if (input.length > 0) {
      this.inputTypeIndicatorTarget.innerHTML = '✍️ <span class="text-gray-600">Text input</span>'
    } else {
      this.inputTypeIndicatorTarget.innerHTML = ''
    }
  }

  updateCharCount() {
    const length = this.inputTarget.value.length
    this.charCountTarget.textContent = `${length} / 500`

    if (length > 450) {
      this.charCountTarget.classList.add('text-orange-600')
    } else {
      this.charCountTarget.classList.remove('text-orange-600')
    }
  }

  async submit(event) {
    event.preventDefault()

    const input = this.inputTarget.value.trim()

    // Validation
    if (input.length < 5) {
      this.showError('Please provide more details (at least 5 characters)')
      return
    }

    if (input.length > 500) {
      this.showError('Input too long (max 500 characters)')
      return
    }

    // Disable submit button
    this.submitButtonTarget.disabled = true
    this.submitTextTarget.textContent = 'Processing...'

    // Show loading state
    this.showLoading()

    try {
      const response = await fetch('/ai_activities/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          input: input,
          request_id: this.requestIdValue
        })
      })

      const data = await response.json()

      if (data.error) {
        this.showError(data.message)
      } else {
        // Result will arrive via Turbo Stream
        // Keep showing loading state
        this.startPollingIfNeeded()
      }
    } catch (error) {
      console.error('Error:', error)
      this.showError('Something went wrong. Please try again.')
    }
  }

  startPollingIfNeeded() {
    // Optional: Poll for status if Turbo Stream doesn't work
    // In production, Turbo Stream should handle this
  }

  showLoading() {
    this.loadingStateTarget.classList.remove('hidden')
    this.suggestionResultTarget.innerHTML = ''
    this.errorStateTarget.classList.add('hidden')
  }

  showError(message) {
    this.errorStateTarget.classList.remove('hidden')
    this.errorStateTarget.querySelector('[data-error-message]').textContent = message
    this.loadingStateTarget.classList.add('hidden')

    // Re-enable submit
    this.submitButtonTarget.disabled = false
    this.submitTextTarget.textContent = 'Generate Activity'
  }
}
```

### 8.4 Stimulus Controller for Suggestion Card

```javascript
// app/javascript/controllers/suggestion_card_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customizePanel"]

  showCustomize(event) {
    event.preventDefault()

    if (this.hasCustomizePanelTarget) {
      this.customizePanelTarget.classList.toggle('hidden')
    }
  }

  async submitFeedback(event) {
    event.preventDefault()

    const feedbackValue = event.target.dataset.feedbackValue // 'helpful' or 'not_helpful'
    const suggestionId = this.element.dataset.suggestionId

    try {
      await fetch(`/ai_activities/${suggestionId}/feedback`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          feedback: feedbackValue
        })
      })

      // Show thank you message
      event.target.disabled = true
      event.target.textContent = '✓ Thanks!'
    } catch (error) {
      console.error('Feedback error:', error)
    }
  }
}
```

---

## 9. Testing Strategy

### 9.1 Test Structure

```
test/
├── services/
│   ├── ai_activity_service_test.rb
│   ├── claude_api_service_test.rb
│   ├── url_extractor_service_test.rb
│   └── activity_scheduling_analyzer_test.rb
├── jobs/
│   └── ai_suggestion_generator_job_test.rb
├── models/
│   ├── ai_activity_suggestion_test.rb
│   └── activity_test.rb (extended)
├── controllers/
│   └── ai_activities_controller_test.rb
├── system/
│   ├── ai_activity_creation_test.rb
│   └── ai_url_extraction_test.rb
└── fixtures/
    ├── vcr_cassettes/
    │   ├── claude_extract_apple_picking.yml
    │   ├── claude_extract_from_eventbrite.yml
    │   └── url_fetch_eventbrite_event.yml
    └── ai_activity_suggestions.yml
```

### 9.2 Service Tests with VCR

```ruby
# test/services/claude_api_service_test.rb

require 'test_helper'

class ClaudeApiServiceTest < ActiveSupport::TestCase
  setup do
    @service = ClaudeApiService.new
  end

  test "extracts activity from natural language input", vcr: true do
    input = "Go apple picking in October"

    VCR.use_cassette("claude_extract_apple_picking") do
      result = @service.extract_activity(input)

      assert_equal "Apple Picking", result['name']
      assert_equal "flexible", result['schedule_type']
      assert_includes result['suggested_months'], 9
      assert_includes result['suggested_months'], 10
      assert_includes result['suggested_days_of_week'], 6 # Saturday
      assert_includes result['suggested_days_of_week'], 7 # Sunday
      assert_equal "afternoon", result['suggested_time_of_day']
    end
  end

  test "extracts recurring activity with schedule details", vcr: true do
    input = "Weekly team standup every Monday at 10am"

    VCR.use_cassette("claude_extract_recurring_meeting") do
      result = @service.extract_activity(input)

      assert_equal "scheduled", result['schedule_type']
      assert_equal "10:00", result['start_time']
      assert_equal [1], result['suggested_days_of_week'] # Monday
      assert_equal 7, result['max_frequency_days']
    end
  end

  test "handles API errors gracefully" do
    # Stub to simulate API error
    Anthropic::Client.any_instance.stubs(:messages).raises(Anthropic::RateLimitError.new("Rate limit exceeded"))

    assert_raises(AiActivityService::AiApiError) do
      @service.extract_activity("Test activity")
    end
  end

  test "retries on retriable errors" do
    # First call fails, second succeeds
    Anthropic::Client.any_instance.stubs(:messages)
      .raises(Anthropic::ServerError.new("Server error"))
      .then.returns({
        'content' => [{ 'text' => '{"name": "Test", "schedule_type": "flexible"}' }]
      })

    result = @service.extract_activity("Test activity")
    assert_equal "Test", result['name']
  end
end
```

### 9.3 URL Extraction Tests

```ruby
# test/services/url_extractor_service_test.rb

require 'test_helper'

class UrlExtractorServiceTest < ActiveSupport::TestCase
  test "extracts Schema.org event from Eventbrite", vcr: true do
    url = "https://www.eventbrite.com/e/example-event-123"

    VCR.use_cassette("url_fetch_eventbrite_event") do
      extractor = UrlExtractorService.new(url)
      result = extractor.extract

      assert_equal false, result[:needs_ai_parsing]
      assert_present result[:structured_data][:name]
      assert_present result[:structured_data][:start_date]
      assert_present result[:structured_data][:location]
    end
  end

  test "rejects localhost URLs (SSRF prevention)" do
    url = "http://localhost:3000/admin"

    extractor = UrlExtractorService.new(url)

    assert_raises(AiActivityService::UrlFetchError) do
      extractor.extract
    end
  end

  test "rejects internal IP URLs (SSRF prevention)" do
    url = "http://192.168.1.1/secret"

    extractor = UrlExtractorService.new(url)

    assert_raises(AiActivityService::UrlFetchError) do
      extractor.extract
    end
  end

  test "caches extracted URL data for 24 hours" do
    url = "https://example.com/event"

    VCR.use_cassette("url_fetch_cacheable_event") do
      # First fetch
      extractor1 = UrlExtractorService.new(url)
      result1 = extractor1.extract

      # Second fetch should hit cache (no HTTP request)
      VCR.turned_off do
        extractor2 = UrlExtractorService.new(url)
        result2 = extractor2.extract

        assert_equal result1, result2
      end
    end
  end
end
```

### 9.4 System Tests

```ruby
# test/system/ai_activity_creation_test.rb

require "application_system_test_case"

class AiActivityCreationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "creating activity from natural language input", vcr: true do
    visit new_ai_activity_path

    fill_in "activity-input", with: "Go apple picking in October"

    VCR.use_cassette("system_test_apple_picking") do
      click_button "Generate Activity"

      # Wait for AI processing (Turbo Stream)
      assert_text "Apple Picking", wait: 10

      # Verify suggestion card appears
      assert_selector "h2", text: "Apple Picking"
      assert_text "Sep-Oct"
      assert_text "Weekends"

      # Accept suggestion
      click_button "Add to Calendar"

      # Verify activity created
      assert_current_path activity_path(Activity.last)
      assert_text "Activity created successfully"
      assert_text "Apple Picking"
    end
  end

  test "customizing AI suggestion before accepting" do
    visit new_ai_activity_path

    fill_in "activity-input", with: "Go hiking"

    VCR.use_cassette("system_test_hiking") do
      click_button "Generate Activity"

      assert_text "Hiking", wait: 10

      # Click customize
      click_button "Customize"

      # Edit fields
      fill_in "Name", with: "Morning Hike at Mt. Tam"
      select "Morning", from: "Time of day"

      click_button "Save Changes"

      # Verify edited activity created
      assert_text "Morning Hike at Mt. Tam"
    end
  end

  test "handling AI errors gracefully" do
    # Stub AI service to fail
    AiActivityService.any_instance.stubs(:generate_suggestion).raises(AiActivityService::AiApiError, "API unavailable")

    visit new_ai_activity_path

    fill_in "activity-input", with: "Test activity"
    click_button "Generate Activity"

    # Verify error message
    assert_text "AI service is temporarily unavailable", wait: 5
    assert_button "Use manual form"
  end
end
```

### 9.5 VCR Configuration

```ruby
# test/test_helper.rb (additions)

require 'vcr'
require 'webmock/minitest'

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock

  # Filter sensitive data
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }

  # Allow connections to test server
  config.ignore_localhost = true

  # Record new episodes when cassettes don't exist
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :body]
  }
end

# Minitest VCR integration
class ActiveSupport::TestCase
  def self.test(name, vcr: false, **opts, &block)
    if vcr
      super(name, **opts) do
        VCR.use_cassette(name.gsub(/\s+/, '_').downcase) do
          instance_eval(&block)
        end
      end
    else
      super(name, **opts, &block)
    end
  end
end
```

---

## 10. Deployment & Monitoring

### 10.1 Environment Configuration

#### Required Environment Variables

```bash
# .env.production (Render.com)

# AI API Keys
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...  # Optional fallback

# Feature Flags
AI_FEATURE_ENABLED=true
AI_MONTHLY_REQUEST_LIMIT=10000

# Cost Management
AI_MONTHLY_BUDGET_USD=1000.00
AI_COST_ALERT_THRESHOLD=0.8  # Alert at 80% of budget

# Rate Limiting
AI_USER_RATE_LIMIT=10  # Requests per minute per user
AI_GLOBAL_RATE_LIMIT=1000  # Requests per minute globally

# Performance
AI_REQUEST_TIMEOUT_SECONDS=15
AI_CACHE_TTL_HOURS=24

# Redis (for distributed rate limiting)
REDIS_URL=redis://...
```

#### Rails Credentials Setup

```bash
# Store API keys in encrypted credentials
bin/rails credentials:edit --environment production

# Add:
anthropic:
  api_key: sk-ant-...

openai:
  api_key: sk-...
```

### 10.2 Infrastructure Requirements

#### Render.com Configuration

```yaml
# render.yaml

services:
  - type: web
    name: sidewalks-web
    env: ruby
    plan: standard  # Upgrade from starter for AI features
    buildCommand: "./bin/render/build.sh"
    startCommand: "bundle exec puma -C config/puma.rb"
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: sidewalks-production
          property: connectionString
      - key: REDIS_URL
        fromService:
          name: sidewalks-redis
          type: redis
          property: connectionString
      - key: ANTHROPIC_API_KEY
        sync: false  # Set manually in Render dashboard
      - key: AI_FEATURE_ENABLED
        value: "true"
      - key: AI_MONTHLY_REQUEST_LIMIT
        value: "10000"
      - key: RAILS_MAX_THREADS
        value: "5"

  # Background job worker
  - type: worker
    name: sidewalks-worker
    env: ruby
    buildCommand: "./bin/render/build.sh"
    startCommand: "bundle exec rake solid_queue:start"
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: sidewalks-production
          property: connectionString
      - key: REDIS_URL
        fromService:
          name: sidewalks-redis
          type: redis
          property: connectionString
      - key: ANTHROPIC_API_KEY
        sync: false
    # Scale up workers for AI jobs
    numInstances: 2  # At least 2 workers
    plan: standard

databases:
  - name: sidewalks-production
    plan: standard  # Upgrade for JSONB performance
    databaseName: sidewalks_production

  - name: sidewalks-redis
    plan: starter
    maxmemoryPolicy: allkeys-lru
    ipAllowList: []  # Allow from all Render services
```

#### Database Connection Pooling

```ruby
# config/database.yml

production:
  <<: *default
  database: sidewalks_production
  url: <%= ENV['DATABASE_URL'] %>

  # Connection pooling for AI workloads
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  prepared_statements: true
  advisory_locks: true

  # Timeouts
  connect_timeout: 5
  checkout_timeout: 5
  reaping_frequency: 10

  # Performance
  statement_timeout: 30000  # 30 seconds

  # For JSONB queries
  variables:
    statement_timeout: 30000
```

#### Solid Queue Worker Configuration

```yaml
# config/solid_queue.yml

production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
      concurrency_maintenance_interval: 300

  workers:
    # General workers
    - queues: "*"
      threads: 3
      processes: 2
      polling_interval: 0.1

    # Dedicated AI processing workers
    - queues: "ai_processing"
      threads: 2
      processes: 2
      polling_interval: 0.5
      max_execution_time: 30  # Kill jobs after 30s
```

### 10.3 Deployment Process

#### Pre-Deployment Checklist

```bash
# 1. Run tests
RAILS_ENV=test bin/rails test

# 2. Check for pending migrations
bin/rails db:migrate:status

# 3. Verify credentials
bin/rails credentials:show --environment production

# 4. Check for security vulnerabilities
bundle exec bundle-audit --update
bin/brakeman

# 5. Test AI API connectivity
bin/rails runner "puts ClaudeApiService.new.extract_activity('test')"

# 6. Verify environment variables
bin/rails runner "
  required_vars = %w[ANTHROPIC_API_KEY AI_FEATURE_ENABLED]
  missing = required_vars.reject { |v| ENV[v].present? }
  abort('Missing env vars: ' + missing.join(', ')) if missing.any?
"
```

#### Deployment Script

```bash
#!/bin/bash
# bin/deploy.sh

set -e

echo "🚀 Deploying AI Activity Suggestions Feature..."

# 1. Run pre-deployment checks
echo "✓ Running pre-deployment checks..."
./bin/pre_deploy_check.sh

# 2. Backup database
echo "✓ Backing up database..."
bin/rails db:backup:create

# 3. Deploy to Render
echo "✓ Deploying to Render..."
git push render main

# 4. Wait for deployment
echo "✓ Waiting for deployment to complete..."
sleep 60

# 5. Run post-deployment checks
echo "✓ Running post-deployment checks..."
curl -f https://sidewalks.app/health || exit 1

# 6. Smoke tests
echo "✓ Running smoke tests..."
bin/rails runner "
  # Test AI suggestion creation
  user = User.first
  suggestion = AiActivityService.new(
    user: user,
    input: 'Test activity'
  ).generate_suggestion

  puts '✓ AI suggestion test passed' if suggestion.is_a?(AiActivitySuggestion)
"

echo "✅ Deployment complete!"
```

#### Database Migration Strategy

```bash
# Run migrations with zero-downtime approach

# 1. Add new columns/tables (non-breaking)
bin/rails db:migrate

# 2. Backfill data if needed (background job)
bin/rails runner "BackfillAiActivityData.perform_later"

# 3. Deploy new code
git push render main

# 4. Remove old columns (after verification)
# Wait 24 hours before removing old schema
```

### 10.4 Monitoring & Observability

#### Application Metrics

```ruby
# app/services/metrics_tracker.rb

class MetricsTracker
  class << self
    def track_ai_suggestion(suggestion)
      # Send to monitoring service (e.g., Datadog, New Relic)

      StatsD.increment('ai.suggestions.created')
      StatsD.histogram('ai.suggestions.processing_time', suggestion.processing_time_ms)
      StatsD.histogram('ai.suggestions.confidence_score', suggestion.confidence_score)
      StatsD.increment("ai.suggestions.input_type.#{suggestion.input_type}")

      if suggestion.accepted?
        StatsD.increment('ai.suggestions.accepted')
      elsif suggestion.rejection_reason.present?
        StatsD.increment('ai.suggestions.rejected')
      end
    end

    def track_ai_error(error_type, details = {})
      StatsD.increment("ai.errors.#{error_type}")

      Rails.logger.error({
        event: 'ai_error',
        error_type: error_type,
        details: details
      }.to_json)
    end

    def track_ai_cost(suggestion)
      cost = suggestion.api_cost_usd || 0
      StatsD.gauge('ai.costs.current_month', monthly_cost)
      StatsD.histogram('ai.costs.per_request', cost)
    end

    private

    def monthly_cost
      AiActivitySuggestion
        .where(created_at: 1.month.ago..)
        .sum(:api_cost_usd)
    end
  end
end
```

#### Key Metrics to Track

```ruby
# config/initializers/metrics.rb

# Custom metrics for AI feature
Rails.application.config.after_initialize do
  # Track these metrics:

  # Usage metrics
  # - ai.suggestions.created (counter)
  # - ai.suggestions.accepted (counter)
  # - ai.suggestions.rejected (counter)
  # - ai.suggestions.processing_time (histogram)
  # - ai.suggestions.confidence_score (histogram)

  # Error metrics
  # - ai.errors.api_timeout (counter)
  # - ai.errors.rate_limit (counter)
  # - ai.errors.parsing_failed (counter)
  # - ai.errors.url_fetch_failed (counter)

  # Cost metrics
  # - ai.costs.current_month (gauge)
  # - ai.costs.per_request (histogram)
  # - ai.costs.per_user (gauge)

  # Performance metrics
  # - ai.cache.hits (counter)
  # - ai.cache.misses (counter)
  # - ai.jobs.queue_depth (gauge)
  # - ai.jobs.processing_time (histogram)
end
```

#### Health Check Endpoint

```ruby
# app/controllers/health_controller.rb

class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    checks = {
      database: check_database,
      redis: check_redis,
      ai_api: check_ai_api,
      job_queue: check_job_queue
    }

    all_healthy = checks.values.all? { |check| check[:status] == 'ok' }
    status = all_healthy ? :ok : :service_unavailable

    render json: {
      status: all_healthy ? 'healthy' : 'unhealthy',
      checks: checks,
      timestamp: Time.current
    }, status: status
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok', latency_ms: measure_latency { ActiveRecord::Base.connection.execute('SELECT 1') } }
  rescue => e
    { status: 'error', error: e.message }
  end

  def check_redis
    Redis.current.ping
    { status: 'ok', latency_ms: measure_latency { Redis.current.ping } }
  rescue => e
    { status: 'error', error: e.message }
  end

  def check_ai_api
    # Quick test request (cached)
    cache_key = 'health_check:ai_api'

    result = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      Timeout.timeout(5) do
        client = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
        response = client.messages(
          model: 'claude-3-5-sonnet-20241022',
          max_tokens: 10,
          messages: [{ role: 'user', content: 'test' }]
        )

        response.present?
      end
    end

    { status: result ? 'ok' : 'degraded' }
  rescue Timeout::Error
    { status: 'timeout' }
  rescue => e
    { status: 'error', error: e.message }
  end

  def check_job_queue
    queue_depth = SolidQueue::Job.where(queue_name: 'ai_processing', finished_at: nil).count

    status = case queue_depth
    when 0..50 then 'ok'
    when 51..100 then 'degraded'
    else 'critical'
    end

    { status: status, queue_depth: queue_depth }
  rescue => e
    { status: 'error', error: e.message }
  end

  def measure_latency
    start = Time.current
    yield
    ((Time.current - start) * 1000).round(2)
  end
end
```

```ruby
# config/routes.rb
get '/health', to: 'health#show'
```

#### Logging Strategy

```ruby
# config/initializers/logging.rb

# Structured logging for AI operations
module AiLogging
  def log_ai_event(event_type, details = {})
    Rails.logger.info({
      event: "ai_#{event_type}",
      user_id: details[:user_id],
      suggestion_id: details[:suggestion_id],
      input_type: details[:input_type],
      processing_time_ms: details[:processing_time_ms],
      confidence_score: details[:confidence_score],
      accepted: details[:accepted],
      timestamp: Time.current.iso8601
    }.compact.to_json)
  end
end

# Usage in services:
class AiActivityService
  include AiLogging

  def generate_suggestion
    # ... existing code ...

    log_ai_event('suggestion_created',
      user_id: user.id,
      suggestion_id: suggestion.id,
      input_type: input_type,
      processing_time_ms: suggestion.processing_time_ms,
      confidence_score: suggestion.confidence_score
    )

    suggestion
  end
end
```

#### Alerting Configuration

```yaml
# config/alerts.yml

alerts:
  # High error rate
  - name: ai_high_error_rate
    condition: ai.errors.* > 10 per 5 minutes
    severity: critical
    notification: pagerduty
    message: "AI error rate elevated: check logs"

  # Cost threshold
  - name: ai_monthly_budget_exceeded
    condition: ai.costs.current_month >= $BUDGET * 0.9
    severity: warning
    notification: slack
    message: "AI costs at 90% of monthly budget"

  # Queue backup
  - name: ai_queue_backup
    condition: ai.jobs.queue_depth > 100
    severity: warning
    notification: slack
    message: "AI job queue depth high: {value} jobs"

  # API latency
  - name: ai_api_slow
    condition: ai.suggestions.processing_time p95 > 10000ms
    severity: warning
    notification: slack
    message: "AI processing slow: p95 = {value}ms"

  # Low acceptance rate
  - name: ai_low_acceptance
    condition: ai.suggestions.accepted / ai.suggestions.created < 0.3 over 1 day
    severity: info
    notification: slack
    message: "AI acceptance rate low: {value}%"
```

#### Dashboard Queries

```ruby
# Example Datadog/Grafana dashboard queries

# AI Usage Over Time
sum:ai.suggestions.created{*}.as_count()

# Acceptance Rate
(sum:ai.suggestions.accepted{*}.as_count() / sum:ai.suggestions.created{*}.as_count()) * 100

# P95 Processing Time
percentile:ai.suggestions.processing_time{*}.p95

# Monthly Cost Burn Rate
cumsum:ai.costs.per_request{*}

# Error Rate by Type
sum:ai.errors.*{*} by {error_type}.as_rate()

# Cache Hit Rate
(sum:ai.cache.hits{*}.as_count() / (sum:ai.cache.hits{*}.as_count() + sum:ai.cache.misses{*}.as_count())) * 100

# Queue Depth
avg:ai.jobs.queue_depth{*}
```

---

## 11. Security Considerations

### 11.1 Authentication & Authorization

#### Feature Access Control

```ruby
# app/models/user.rb

class User < ApplicationRecord
  # Feature flags
  def can_use_ai_features?
    return false unless ENV.fetch('AI_FEATURE_ENABLED', 'false') == 'true'

    # Check subscription/plan
    return false if free_tier? && ai_requests_this_month >= 10

    # Check account status
    return false if suspended? || deactivated?

    true
  end

  def ai_requests_this_month
    ai_activity_suggestions.where(created_at: 1.month.ago..).count
  end

  def ai_budget_remaining
    plan_budget = case plan
    when 'free' then 5.00
    when 'pro' then 50.00
    when 'enterprise' then Float::INFINITY
    else 0
    end

    spent = ai_activity_suggestions
      .where(created_at: 1.month.ago..)
      .sum(:api_cost_usd)

    plan_budget - spent
  end
end
```

#### Controller Authorization

```ruby
# app/controllers/ai_activities_controller.rb

class AiActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :check_ai_feature_enabled
  before_action :check_user_ai_access
  before_action :set_suggestion, only: [:accept, :reject, :feedback]
  before_action :authorize_suggestion, only: [:accept, :reject, :feedback]

  private

  def check_user_ai_access
    unless current_user.can_use_ai_features?
      respond_to do |format|
        format.html do
          redirect_to activities_path,
            alert: 'AI features are not available on your current plan'
        end
        format.json do
          render json: {
            error: 'AI features not available',
            upgrade_url: upgrade_path
          }, status: :forbidden
        end
      end
    end
  end

  def authorize_suggestion
    unless @suggestion.user_id == current_user.id
      raise ActiveRecord::RecordNotFound
    end
  end
end
```

### 11.2 Input Validation & Sanitization

#### Comprehensive Input Sanitization

```ruby
# app/services/input_sanitizer.rb

class InputSanitizer
  ALLOWED_TAGS = %w[].freeze
  MAX_LENGTH = 500
  MIN_LENGTH = 5

  class << self
    def sanitize_text_input(input)
      # 1. Strip whitespace
      cleaned = input.to_s.strip

      # 2. Remove HTML tags
      cleaned = ActionController::Base.helpers.sanitize(cleaned, tags: ALLOWED_TAGS)

      # 3. Remove control characters
      cleaned = cleaned.gsub(/[\x00-\x1F\x7F]/, '')

      # 4. Normalize unicode
      cleaned = cleaned.unicode_normalize(:nfc)

      # 5. Truncate to max length
      cleaned = cleaned.truncate(MAX_LENGTH, omission: '')

      # 6. Validate length
      validate_length!(cleaned)

      cleaned
    end

    def sanitize_url_input(url)
      # 1. Parse and normalize
      uri = Addressable::URI.parse(url).normalize

      # 2. Validate scheme
      unless uri.scheme.match?(/^https?$/)
        raise SecurityError, "Invalid URL scheme: #{uri.scheme}"
      end

      # 3. Validate host (SSRF prevention)
      validate_host!(uri.host)

      # 4. Remove sensitive query params
      uri.query_values = (uri.query_values || {}).except('token', 'key', 'password')

      uri.to_s
    rescue Addressable::URI::InvalidURIError => e
      raise SecurityError, "Invalid URL: #{e.message}"
    end

    private

    def validate_length!(text)
      if text.length < MIN_LENGTH
        raise ArgumentError, "Input too short (minimum #{MIN_LENGTH} characters)"
      end

      if text.length > MAX_LENGTH
        raise ArgumentError, "Input too long (maximum #{MAX_LENGTH} characters)"
      end
    end

    def validate_host!(host)
      return if host.nil?

      # Block localhost
      if host.match?(/^(localhost|127\.|::1)/)
        raise SecurityError, "Localhost URLs not allowed"
      end

      # Block private IP ranges
      if host.match?(/^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)/)
        raise SecurityError, "Private IP addresses not allowed"
      end

      # Block metadata endpoints
      if host.match?(/169\.254\.|metadata/)
        raise SecurityError, "Metadata endpoints not allowed"
      end
    end
  end
end
```

#### Usage in Controllers

```ruby
def generate
  # Sanitize input
  input = InputSanitizer.sanitize_text_input(params[:input])

  # Detect and validate URL
  if input.match?(/^https?:/)
    input = InputSanitizer.sanitize_url_input(input)
  end

  # ... rest of action
rescue SecurityError => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

### 11.3 Output Escaping (XSS Prevention)

#### View Helpers with Auto-Escaping

```ruby
# app/helpers/ai_activities_helper.rb

module AiActivitiesHelper
  # All helper methods auto-escape by default in Rails
  # But be extra careful with AI-generated content

  def safe_ai_field(suggestion, field)
    value = suggestion.suggested_data[field]
    sanitize(value, tags: [], attributes: [])
  end

  def safe_ai_description(suggestion)
    description = suggestion.suggested_data['description']

    # Allow basic formatting but strip dangerous tags
    sanitize(description,
      tags: %w[p br strong em],
      attributes: []
    )
  end

  def safe_ai_url(url)
    # Ensure URL is safe before rendering
    return '#' if url.blank?

    uri = URI.parse(url)
    return '#' unless uri.scheme.in?(['http', 'https'])

    url
  rescue URI::InvalidURIError
    '#'
  end
end
```

#### Content Security Policy

```ruby
# config/initializers/content_security_policy.rb

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data, :blob
  policy.object_src  :none
  policy.script_src  :self, :https
  policy.style_src   :self, :https

  # Allow AI API endpoints
  policy.connect_src :self, :https,
    'https://api.anthropic.com',
    'https://api.openai.com'

  # Prevent inline scripts
  # policy.script_src :self  # Remove :unsafe_inline if present

  # Report violations
  if Rails.env.production?
    policy.report_uri "/csp-violation-report"
  end
end

# Enable CSP
Rails.application.config.content_security_policy_nonce_generator =
  ->(request) { SecureRandom.base64(16) }

Rails.application.config.content_security_policy_nonce_directives =
  %w[script-src style-src]
```

### 11.4 API Security

#### Rate Limiting (Rack::Attack)

```ruby
# config/initializers/rack_attack.rb

class Rack::Attack
  # Rate limit AI endpoints
  throttle('ai/ip', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/ai_activities')
      req.ip
    end
  end

  throttle('ai/user', limit: 10, period: 1.minute) do |req|
    if req.path.start_with?('/ai_activities') && req.env['warden'].user
      req.env['warden'].user.id
    end
  end

  # Block suspicious requests
  blocklist('block suspicious AI requests') do |req|
    if req.path.start_with?('/ai_activities')
      # Block if input contains obvious injection attempts
      input = req.params['input'].to_s

      # SQL injection patterns
      input.match?(/(\bunion\b.*\bselect\b|\bdrop\b.*\btable\b)/i) ||
      # Script injection patterns
      input.match?(/<script|javascript:|onerror=/i) ||
      # Command injection patterns
      input.match?(/[;&|`$]/)
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    [
      429,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Rate limit exceeded', retry_after: 60 }.to_json]
    ]
  end
end
```

#### Secure Turbo Stream Channels

```ruby
# app/channels/ai_suggestions_channel.rb

class AiSuggestionsChannel < ApplicationCable::Channel
  def subscribed
    # Verify user owns this channel
    user_id = params[:user_id].to_i

    if current_user.nil? || current_user.id != user_id
      reject
      return
    end

    stream_from "ai_suggestions_#{user_id}"
  end

  def unsubscribed
    stop_all_streams
  end
end
```

```ruby
# app/channels/application_cable/connection.rb

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      if verified_user = env['warden'].user
        verified_user
      else
        reject_unauthorized_connection
      end
    end
  end
end
```

### 11.5 Data Protection

#### Encryption at Rest

```ruby
# config/initializers/active_record_encryption.rb

# Already configured for activities, extend to AI suggestions
ActiveRecord::Encryption.configure(
  primary_key: ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'),
  deterministic_key: ENV.fetch('ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY'),
  key_derivation_salt: ENV.fetch('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT')
)
```

```ruby
# app/models/ai_activity_suggestion.rb

class AiActivitySuggestion < ApplicationRecord
  # Encrypt sensitive fields
  encrypts :input_text, deterministic: false
  encrypts :api_request, deterministic: false
  encrypts :api_response, deterministic: false
end
```

#### PII Scrubbing

```ruby
# app/services/pii_scrubber.rb

class PiiScrubber
  EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i
  PHONE_REGEX = /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/
  SSN_REGEX = /\b\d{3}-\d{2}-\d{4}\b/
  CREDIT_CARD_REGEX = /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/

  class << self
    def scrub(text)
      return text if text.blank?

      scrubbed = text.dup
      scrubbed.gsub!(EMAIL_REGEX, '[EMAIL]')
      scrubbed.gsub!(PHONE_REGEX, '[PHONE]')
      scrubbed.gsub!(SSN_REGEX, '[SSN]')
      scrubbed.gsub!(CREDIT_CARD_REGEX, '[CARD]')

      scrubbed
    end
  end
end
```

```ruby
# Use before sending to AI
def extract_activity(user_input)
  # Scrub PII before sending to external API
  scrubbed_input = PiiScrubber.scrub(user_input)

  response = @client.messages(
    messages: [{ role: 'user', content: "Activity description: #{scrubbed_input}" }],
    system: SYSTEM_PROMPT
  )

  # ... rest of method
end
```

#### Data Retention Policy

```ruby
# app/jobs/data_cleanup_job.rb

class DataCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    # Delete rejected suggestions after 90 days
    AiActivitySuggestion
      .where(accepted: false)
      .where('created_at < ?', 90.days.ago)
      .where.not(final_activity_id: nil)
      .delete_all

    # Anonymize old suggestions (keep for analytics)
    AiActivitySuggestion
      .where('created_at < ?', 1.year.ago)
      .update_all(
        input_text: '[ANONYMIZED]',
        api_request: {},
        api_response: {}
      )

    Rails.logger.info("Data cleanup complete")
  end
end
```

```ruby
# Schedule in cron
# config/schedule.rb (if using whenever gem)
every 1.day, at: '2:00 am' do
  runner "DataCleanupJob.perform_later"
end
```

---

## 12. Phase Rollout Plan

### 12.1 Pre-Launch Preparation (Week -2 to -1)

#### Week -2: Internal Testing

```
Day 1-2: Development Environment Setup
├─ Set up Anthropic API account
├─ Configure API keys in dev credentials
├─ Run migrations on dev database
└─ Seed test data

Day 3-4: Feature Testing
├─ Test text input flow end-to-end
├─ Test URL extraction with real events
├─ Test error scenarios (API down, timeout, etc.)
├─ Verify rate limiting works
└─ Check cost tracking accuracy

Day 5: Performance Testing
├─ Load test with 100 concurrent requests
├─ Monitor memory usage
├─ Check database query performance
└─ Verify caching effectiveness
```

#### Week -1: Staging Deployment

```
Day 1: Deploy to Staging
├─ Run migrations on staging database
├─ Deploy application code
├─ Configure environment variables
└─ Verify health checks pass

Day 2-3: Internal Alpha Testing
├─ Invite 10 team members to test
├─ Track usage and gather feedback
├─ Monitor for errors and performance issues
└─ Fix critical bugs

Day 4-5: Security Audit
├─ Run security scans (OWASP ZAP, etc.)
├─ Review SSRF prevention
├─ Test authentication/authorization
├─ Verify XSS protection
└─ Check CSP implementation
```

### 12.2 Phase 1: Limited Beta (Week 1-2)

#### Rollout Strategy

```ruby
# app/models/user.rb

# Feature flag with gradual rollout
def can_use_ai_features?
  return false unless ENV['AI_FEATURE_ENABLED'] == 'true'

  # Phase 1: Beta users only
  if Rails.cache.read('ai_feature:phase') == 'beta'
    return beta_user? || team_member?
  end

  # Phase 2: All users
  true
end

def beta_user?
  # Users who opted into beta
  beta_opt_in? || id.in?(ENV['AI_BETA_USER_IDS']&.split(',')&.map(&:to_i) || [])
end
```

#### Week 1: Invite 50 Beta Users

```
Day 1: Launch Announcement
├─ Email beta invite to 50 selected users
├─ Enable AI_FEATURE_ENABLED flag
├─ Set ai_feature:phase = 'beta'
└─ Monitor dashboards

Day 2-3: Close Monitoring
├─ Watch error rates (target: <2%)
├─ Monitor API costs (budget: $50 for 500 requests)
├─ Track acceptance rate (target: >60%)
├─ Collect user feedback
└─ Fix bugs as they arise

Day 4-5: Iteration
├─ Deploy hotfixes based on feedback
├─ Adjust prompts if needed
├─ Optimize slow queries
└─ Update documentation
```

#### Week 2: Expand to 200 Users

```
Day 1: Expand Beta
├─ Invite additional 150 users
├─ Monitor infrastructure scaling
└─ Increase budget to $200

Day 2-5: Stabilization
├─ Address feedback from larger user base
├─ Tune caching for better hit rates
├─ Optimize AI prompts for accuracy
└─ Prepare for public launch
```

### 12.3 Phase 2: Public Launch (Week 3-4)

#### Week 3: Gradual Rollout

```
Day 1: 10% of Users
├─ Remove beta flag requirement
├─ Enable for 10% of users (by user_id % 10 == 0)
├─ Monitor closely for 24 hours
└─ Budget: $500/week

Day 2: 25% of Users (if no issues)
├─ Increase to 25% (user_id % 4 == 0)
├─ Monitor metrics
└─ Scale infrastructure if needed

Day 3: 50% of Users
├─ Increase to 50% (user_id % 2 == 0)
├─ Verify costs are within budget
└─ Monitor acceptance rates

Day 4-5: 100% Rollout
├─ Enable for all users
├─ Marketing announcement
├─ Monitor for traffic spikes
└─ On-call engineer ready
```

#### Week 4: Optimization & Stabilization

```
Day 1-2: Performance Tuning
├─ Analyze slow queries
├─ Optimize cache hit rates
├─ Review AI prompt effectiveness
└─ Adjust rate limits if needed

Day 3-4: Cost Optimization
├─ Review per-user costs
├─ Implement additional caching
├─ Consider cheaper AI models for simple inputs
└─ Set up cost alerts

Day 5: Retrospective
├─ Review metrics vs targets
├─ Document lessons learned
├─ Plan Phase 3 (Power User Features)
└─ Celebrate launch! 🎉
```

### 12.4 Success Criteria

#### Metrics Targets (4 weeks post-launch)

```yaml
Usage Metrics:
  adoption_rate: ">= 40%"  # % of users who try AI feature
  repeat_usage: ">= 60%"   # % who use it again
  ai_vs_manual: ">= 30%"   # % of activities created via AI

Quality Metrics:
  acceptance_rate: ">= 65%"     # % of suggestions accepted
  edit_rate: "<= 35%"           # % requiring edits
  confidence_avg: ">= 80"       # Average confidence score

Performance Metrics:
  p50_response_time: "< 3s"
  p95_response_time: "< 10s"
  error_rate: "< 2%"
  uptime: ">= 99.5%"

Cost Metrics:
  cost_per_suggestion: "< $0.01"
  monthly_total: "< $1000"
  roi: "> 100%"  # Value delivered vs cost

User Satisfaction:
  nps_score: ">= 40"
  support_tickets: "< 5 per 1000 users"
  positive_feedback: ">= 70%"
```

### 12.5 Rollback Plan

#### Triggers for Rollback

```
Immediate Rollback if:
├─ Error rate > 10%
├─ API costs > $5000/day
├─ Data corruption detected
├─ Security vulnerability discovered
└─ Uptime < 95% over 1 hour

Gradual Rollback if:
├─ Error rate > 5% for 24 hours
├─ Acceptance rate < 40% for 3 days
├─ User complaints spike
└─ Infrastructure strain
```

#### Rollback Procedure

```bash
#!/bin/bash
# bin/rollback_ai_feature.sh

set -e

echo "🚨 Rolling back AI feature..."

# 1. Disable feature flag
heroku config:set AI_FEATURE_ENABLED=false --app sidewalks-production

# 2. Stop AI background workers
heroku ps:scale worker=0:ai_processing --app sidewalks-production

# 3. Revert code deployment
git revert HEAD --no-edit
git push heroku main

# 4. Monitor for stability
sleep 60
curl -f https://sidewalks.app/health || exit 1

echo "✅ Rollback complete. Feature disabled."
echo "🔍 Investigate issues before re-enabling."
```

### 12.6 Go/No-Go Checklist

#### Pre-Launch Checklist (Must all be ✅)

```
Technical Readiness:
☐ All tests passing (unit, integration, system)
☐ Security scan passed (0 critical vulnerabilities)
☐ Performance tests passed (p95 < 10s)
☐ Health checks working
☐ Monitoring dashboards configured
☐ Alerts configured and tested
☐ Rollback plan tested

Infrastructure:
☐ Database upgraded to support load
☐ Redis configured and tested
☐ Background workers scaled (min 2)
☐ API keys configured securely
☐ Rate limiting tested
☐ Caching verified

Documentation:
☐ User guide published
☐ API documentation complete
☐ Incident runbook prepared
☐ Team trained on features
☐ Support team briefed

Business Readiness:
☐ Budget approved ($1000/month)
☐ Cost tracking implemented
☐ Acceptance criteria defined
☐ Success metrics agreed upon
☐ Marketing materials ready
☐ Beta feedback incorporated
```

---

## 13. Appendix

### 13.1 Environment Variable Reference

```bash
# Complete list of environment variables

# Required
ANTHROPIC_API_KEY=sk-ant-...
DATABASE_URL=postgresql://...
REDIS_URL=redis://...

# AI Feature Configuration
AI_FEATURE_ENABLED=true
AI_MONTHLY_REQUEST_LIMIT=10000
AI_MONTHLY_BUDGET_USD=1000.00
AI_COST_ALERT_THRESHOLD=0.8
AI_REQUEST_TIMEOUT_SECONDS=15
AI_CACHE_TTL_HOURS=24

# Rate Limiting
AI_USER_RATE_LIMIT=10
AI_GLOBAL_RATE_LIMIT=1000

# Optional Fallback
OPENAI_API_KEY=sk-...

# Rails
RAILS_ENV=production
RAILS_MAX_THREADS=5
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# Active Record Encryption
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
```

### 13.2 Useful Commands

```bash
# Monitor AI usage
bin/rails runner "puts AiActivitySuggestion.group(:input_type).count"

# Check monthly costs
bin/rails runner "puts AiActivitySuggestion.where(created_at: 1.month.ago..).sum(:api_cost_usd)"

# Acceptance rate
bin/rails runner "
  total = AiActivitySuggestion.count
  accepted = AiActivitySuggestion.where(accepted: true).count
  puts \"Acceptance rate: #{(accepted.to_f / total * 100).round(1)}%\"
"

# Clear AI cache
bin/rails runner "Rails.cache.delete_matched('ai_suggestion:*')"

# Test AI API connection
bin/rails runner "
  service = ClaudeApiService.new
  result = service.extract_activity('Test activity')
  puts result.inspect
"

# Monitor job queue
bin/rails runner "
  puts \"AI jobs in queue: #{SolidQueue::Job.where(queue_name: 'ai_processing', finished_at: nil).count}\"
"
```

### 13.3 Troubleshooting Guide

```
Common Issues:

1. AI API Timeouts
   Symptom: Processing takes > 15 seconds
   Cause: Anthropic API slow or unavailable
   Fix: Check API status, increase timeout, or enable fallback

2. High Error Rate
   Symptom: Error rate > 5%
   Cause: Invalid input, API issues, or bugs
   Fix: Check logs, validate inputs, contact API support

3. Low Acceptance Rate
   Symptom: < 50% of suggestions accepted
   Cause: Poor AI prompts or bad suggestions
   Fix: Review rejected suggestions, improve prompts

4. High Costs
   Symptom: Monthly costs > budget
   Cause: High usage or inefficient caching
   Fix: Increase cache hit rate, optimize prompts

5. Queue Backup
   Symptom: Jobs not processing
   Cause: Workers down or overloaded
   Fix: Scale workers, check for stuck jobs
```

---

## 14. Conclusion

This technical implementation plan provides a complete, production-ready roadmap for building the AI Activity Suggestions feature. The architecture is scalable, secure, and cost-effective.

### Key Takeaways

✅ **Well-Architected**: Clean separation of concerns, service-oriented
✅ **Security-First**: SSRF prevention, XSS protection, rate limiting
✅ **Observable**: Comprehensive monitoring and logging
✅ **Cost-Managed**: Budget tracking and alerts
✅ **Tested**: VCR for external APIs, comprehensive test coverage
✅ **Scalable**: Background jobs, caching, connection pooling

### Next Steps

1. Review and approve this implementation plan
2. Set up Anthropic API account
3. Begin Phase 1: Database migrations and models
4. Implement service layer with tests
5. Build controller and views
6. Deploy to staging for internal testing
7. Launch beta program
8. Public rollout

**Estimated Timeline**: 6 weeks from start to public launch

---

*End of Technical Implementation Document*

**Document Version**: 1.0
**Last Updated**: 2025-11-08
**Status**: Complete and Ready for Implementation