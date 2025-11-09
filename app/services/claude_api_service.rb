class ClaudeApiService
  class ApiError < StandardError; end
  class RateLimitError < ApiError; end
  class InvalidResponseError < ApiError; end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an AI assistant helping users plan and organize activities.

    Your task is to extract structured information from natural language descriptions or web content
    and suggest optimal scheduling parameters.

    Return a JSON object with the following structure:
    {
      "name": "Activity name (concise, 2-50 characters)",
      "description": "Detailed description (optional, up to 500 characters)",
      "schedule_type": "flexible|strict|deadline",
      "suggested_months": [1, 2, 3],  // Array of month numbers (1=Jan, 12=Dec), empty for year-round
      "suggested_days_of_week": [0, 6],  // Array (0=Sunday, 6=Saturday), empty for any day
      "suggested_time_of_day": "morning|afternoon|evening|night",  // or null for flexible
      "category_tags": ["outdoor", "social", "exercise"],  // Max 5 relevant tags
      "duration_estimate": "30 minutes|1-2 hours|half day|full day",
      "confidence_score": 85,  // 0-100, your confidence in these suggestions
      "reasoning": "Brief explanation of scheduling recommendations"
    }

    Scheduling guidelines:
    - "flexible": Activities that can happen any time (e.g., "call mom", "read a book")
    - "strict": Time-sensitive events with specific start/end times (e.g., "dentist appointment at 2pm")
    - "deadline": Tasks with a due date (e.g., "finish report by Friday")

    Month suggestions:
    - Consider seasonal appropriateness (e.g., skiing in winter months, beach in summer)
    - Empty array means activity is suitable year-round

    Day of week suggestions:
    - Consider social norms (e.g., bars/restaurants on weekends, errands on weekdays)
    - Empty array means any day is suitable

    Time of day:
    - morning: 6am-12pm
    - afternoon: 12pm-5pm
    - evening: 5pm-9pm
    - night: 9pm-late
    - null: flexible/not time-specific

    Be thoughtful and use common sense. If uncertain, lean toward flexibility.
  PROMPT

  def initialize
    @api_key = ENV.fetch('ANTHROPIC_API_KEY') { raise ApiError, 'ANTHROPIC_API_KEY not configured' }
    @model = 'claude-3-5-sonnet-20241022'
  end

  # Extract activity from natural language text
  # @param user_input [String] the user's description of the activity
  # @return [Hash] structured activity data
  def extract_activity_from_text(user_input)
    prompt = <<~TEXT
      Extract activity information from this user description:

      "#{user_input}"

      Return only the JSON object, no other text.
    TEXT

    response = call_claude_api(prompt)
    parse_json_response(response)
  end

  # Extract activity from URL/web content
  # @param url [String] the source URL
  # @param html_content [String] the HTML content to parse
  # @param structured_data [Hash] any pre-extracted structured data
  # @return [Hash] structured activity data
  def extract_activity_from_url(url:, html_content: nil, structured_data: {})
    prompt = build_url_extraction_prompt(url, html_content, structured_data)
    response = call_claude_api(prompt)
    parse_json_response(response)
  end

  private

  def call_claude_api(user_message)
    uri = URI('https://api.anthropic.com/v1/messages')
    request = build_request(uri, user_message)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
      http.request(request)
    end

    handle_response(response)
  rescue Net::ReadTimeout => e
    raise ApiError, "API request timed out: #{e.message}"
  rescue RateLimitError, InvalidResponseError
    raise
  rescue StandardError => e
    raise ApiError, "API request failed: #{e.message}"
  end

  def build_request(uri, user_message)
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = @api_key
    request['anthropic-version'] = '2023-06-01'

    request.body = {
      model: @model,
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: 'user',
          content: user_message
        }
      ]
    }.to_json

    request
  end

  def handle_response(response)
    case response.code.to_i
    when 200
      body = JSON.parse(response.body)
      extract_content(body)
    when 429
      raise RateLimitError, 'API rate limit exceeded'
    when 400..499
      error_message = JSON.parse(response.body).dig('error', 'message') rescue 'Unknown error'
      raise ApiError, "API client error: #{error_message}"
    when 500..599
      raise ApiError, 'API server error'
    else
      raise ApiError, "Unexpected response code: #{response.code}"
    end
  rescue JSON::ParserError => e
    raise ApiError, "Failed to parse API response: #{e.message}"
  end

  def extract_content(response_body)
    content = response_body.dig('content', 0, 'text')
    raise InvalidResponseError, 'No content in API response' unless content

    {
      content: content,
      usage: response_body['usage'],
      model: response_body['model']
    }
  end

  def parse_json_response(api_response)
    content = api_response[:content]

    # Try to extract JSON from markdown code blocks if present
    json_match = content.match(/```json\s*(\{.*?\})\s*```/m) ||
                 content.match(/```\s*(\{.*?\})\s*```/m) ||
                 content.match(/(\{.*\})/m)

    json_str = json_match ? json_match[1] : content
    parsed = JSON.parse(json_str)

    # Add API metadata
    parsed['api_metadata'] = {
      model: api_response[:model],
      usage: api_response[:usage]
    }

    validate_response_structure(parsed)
    parsed
  rescue JSON::ParserError => e
    raise InvalidResponseError, "Failed to parse JSON from AI response: #{e.message}\nContent: #{content}"
  end

  def validate_response_structure(data)
    required_fields = %w[name schedule_type confidence_score]
    missing_fields = required_fields - data.keys

    if missing_fields.any?
      raise InvalidResponseError, "Missing required fields: #{missing_fields.join(', ')}"
    end

    unless %w[flexible strict deadline].include?(data['schedule_type'])
      raise InvalidResponseError, "Invalid schedule_type: #{data['schedule_type']}"
    end

    score = data['confidence_score']
    unless score.is_a?(Numeric) && score >= 0 && score <= 100
      raise InvalidResponseError, "Invalid confidence_score: #{score}"
    end
  end

  def build_url_extraction_prompt(url, html_content, structured_data)
    prompt = <<~TEXT
      Extract activity information from this web page:

      URL: #{url}
    TEXT

    if structured_data.present?
      prompt += <<~TEXT

        Pre-extracted structured data (Schema.org/OpenGraph):
        #{JSON.pretty_generate(structured_data)}
      TEXT
    end

    if html_content.present?
      # Truncate HTML to avoid token limits (keep first 8000 chars)
      truncated_html = html_content[0, 8000]
      prompt += <<~TEXT

        Page content (truncated):
        #{truncated_html}
      TEXT
    end

    prompt += "\n\nReturn only the JSON object, no other text."
    prompt
  end
end
