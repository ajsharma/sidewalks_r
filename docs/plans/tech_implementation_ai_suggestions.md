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

*To be continued in next section...*

This is getting quite long! Shall I continue with:
- Section 7: Controller Implementation
- Section 8: View Layer & Stimulus Controllers
- Section 9: Testing Strategy
- Section 10: Deployment & Monitoring

Or would you like me to focus on a specific section first?