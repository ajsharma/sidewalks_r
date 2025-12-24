require "feedjira"
require "net/http"
require "uri"

# Service for parsing RSS/Atom feeds and extracting event data.
# Handles multiple feed formats with custom parsing strategies.
class RssParserService
  # Raised when feed URL is invalid or blocked
  class InvalidUrlError < StandardError; end
  # Raised when feed fetch fails due to network issues
  class FetchError < StandardError; end
  # Raised when feed parsing fails
  class ParseError < StandardError; end

  TIMEOUT_SECONDS = 30
  MAX_REDIRECTS = 5
  MAX_CONTENT_LENGTH = 10_000_000 # 10MB for feeds

  # Blocked hosts for SSRF prevention (inherited from UrlExtractorService pattern)
  BLOCKED_PATTERNS = [
    /^localhost$/i,
    /^127\./,
    /^192\.168\./,
    /^10\./,
    /^172\.(1[6-9]|2[0-9]|3[01])\./,
    /^169\.254\./,
    /^::1$/,
    /^fe80:/i,
    /^metadata\.google\.internal$/i
  ].freeze

  def initialize(feed_url)
    @feed_url = feed_url.strip
    @uri = parse_and_validate_url!
  end

  # Main parsing method
  # @return [Array<Hash>] array of event hashes
  def parse
    xml_content = fetch_feed_content
    parsed_feed = Feedjira.parse(xml_content)

    raise ParseError, "Failed to parse feed" unless parsed_feed

    extract_events_from_feed(parsed_feed)
  rescue Feedjira::NoParserAvailable => e
    raise ParseError, "No parser available for feed format: #{e.message}"
  end

  private

  def parse_and_validate_url!
    uri = URI.parse(@feed_url)

    unless %w[http https].include?(uri.scheme&.downcase)
      raise InvalidUrlError, "URL must use HTTP or HTTPS protocol"
    end

    raise InvalidUrlError, "URL must have a valid host" unless uri.host

    if BLOCKED_PATTERNS.any? { |pattern| uri.host.match?(pattern) }
      raise InvalidUrlError, "URL host is not allowed (private/internal network)"
    end

    if uri.host.match?(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)
      raise InvalidUrlError, "Direct IP addresses are not allowed"
    end

    uri
  rescue URI::InvalidURIError => e
    raise InvalidUrlError, "Invalid URL format: #{e.message}"
  end

  def fetch_feed_content(redirect_count = 0)
    raise FetchError, "Too many redirects" if redirect_count >= MAX_REDIRECTS

    response = make_http_request

    case response
    when Net::HTTPSuccess
      validate_content_length(response)
      response.body
    when Net::HTTPRedirection
      location = response["location"]
      raise FetchError, "Redirect with no location" unless location

      @uri = parse_and_validate_url_from_redirect(location)
      fetch_feed_content(redirect_count + 1)
    else
      raise FetchError, "HTTP error: #{response.code} #{response.message}"
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise FetchError, "Request timed out: #{e.message}"
  rescue SocketError => e
    raise FetchError, "Could not resolve host: #{e.message}"
  rescue StandardError => e
    raise FetchError, "Failed to fetch feed: #{e.message}"
  end

  def make_http_request
    Net::HTTP.start(
      @uri.host,
      @uri.port,
      use_ssl: @uri.scheme == "https",
      open_timeout: TIMEOUT_SECONDS,
      read_timeout: TIMEOUT_SECONDS,
      verify_mode: OpenSSL::SSL::VERIFY_PEER,
      ca_file: ENV["SSL_CERT_FILE"] || OpenSSL::X509::DEFAULT_CERT_FILE
    ) do |http|
      request = Net::HTTP::Get.new(@uri.request_uri)
      request["User-Agent"] = "SidewalksBot/1.0 (Activity Discovery RSS Reader)"
      http.request(request)
    end
  end

  def validate_content_length(response)
    content_length = response["content-length"]&.to_i
    if content_length && content_length > MAX_CONTENT_LENGTH
      raise FetchError, "Content too large: #{content_length} bytes"
    end
  end

  def parse_and_validate_url_from_redirect(location)
    redirect_uri = location.start_with?("http") ? URI.parse(location) : @uri + location

    if BLOCKED_PATTERNS.any? { |pattern| redirect_uri.host.match?(pattern) }
      raise InvalidUrlError, "Redirect to blocked host"
    end

    redirect_uri
  end

  def extract_events_from_feed(feed)
    events = []

    feed.entries.each do |entry|
      begin
        event_data = parse_entry(entry)
        events << event_data if event_data && valid_event?(event_data)
      rescue StandardError => e
        Rails.logger.warn("Failed to parse feed entry: #{e.message}")
        next
      end
    end

    events
  end

  def parse_entry(entry)
    # Determine feed source and use appropriate parsing strategy
    if @feed_url.include?("funcheap.com")
      parse_funcheap_entry(entry)
    elsif @feed_url.include?("bottomofthehill.com")
      parse_bottom_of_the_hill_entry(entry)
    elsif @feed_url.include?("eddies-list.com")
      parse_eddies_list_entry(entry)
    else
      parse_generic_entry(entry)
    end
  end

  def parse_funcheap_entry(entry)
    # FunCheap uses custom namespace ev:* for event data
    start_time = parse_date(entry.try(:ev_startdate) || entry.published)
    end_time = parse_date(entry.try(:ev_enddate))

    {
      title: sanitize_text(entry.title),
      description: sanitize_html(entry.summary || entry.content),
      start_time: start_time,
      end_time: end_time,
      location: sanitize_text(entry.try(:ev_location)),
      venue: sanitize_text(entry.try(:ev_location)),
      source_url: entry.url,
      price: parse_price(entry.try(:ev_price)),
      organizer: sanitize_text(entry.try(:ev_organizer) || entry.author),
      category_tags: extract_categories(entry),
      external_id: entry.entry_id || entry.url
    }
  end

  def parse_bottom_of_the_hill_entry(entry)
    # Bottom of the Hill includes date in title like "Fri, Dec 20: Band Name"
    date_from_title = extract_date_from_title(entry.title)
    start_time = date_from_title || parse_date(entry.published)

    {
      title: clean_bottom_of_hill_title(entry.title),
      description: sanitize_html(entry.summary || entry.content),
      start_time: start_time,
      end_time: nil,
      location: "Bottom of the Hill, San Francisco, CA",
      venue: "Bottom of the Hill",
      source_url: entry.url,
      price: nil, # Usually requires clicking through
      organizer: "Bottom of the Hill",
      category_tags: [ "music", "concert", "live performance" ],
      external_id: entry.entry_id || entry.url
    }
  end

  def parse_eddies_list_entry(entry)
    {
      title: sanitize_text(entry.title),
      description: sanitize_html(entry.summary || entry.content),
      start_time: parse_date(entry.published),
      end_time: nil,
      location: extract_location_from_description(entry.summary || entry.content),
      venue: nil,
      source_url: entry.url,
      price: nil,
      organizer: sanitize_text(entry.author),
      category_tags: extract_categories(entry),
      external_id: entry.entry_id || entry.url
    }
  end

  def parse_generic_entry(entry)
    {
      title: sanitize_text(entry.title),
      description: sanitize_html(entry.summary || entry.content),
      start_time: parse_date(entry.published),
      end_time: nil,
      location: nil,
      venue: nil,
      source_url: entry.url,
      price: nil,
      organizer: sanitize_text(entry.author),
      category_tags: extract_categories(entry),
      external_id: entry.entry_id || entry.url
    }
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    return date_string if date_string.is_a?(Time) || date_string.is_a?(DateTime)

    Time.zone.parse(date_string.to_s)
  rescue ArgumentError
    nil
  end

  def parse_price(price_string)
    return nil if price_string.blank?

    # Extract numeric value from string like "$15", "15.00", "Free"
    return 0.0 if price_string.to_s.downcase.include?("free")

    price_match = price_string.to_s.match(/[\d.]+/)
    price_match ? price_match[0].to_f : nil
  end

  def extract_date_from_title(title)
    # Pattern: "Fri, Dec 20: Band Name" or "Sat Dec 20: Event"
    # Try to match various date formats in title
    date_patterns = [
      /(\w{3},?\s+\w{3}\s+\d{1,2})/i,  # "Fri, Dec 20" or "Fri Dec 20"
      /(\d{1,2}\/\d{1,2}\/\d{2,4})/,    # "12/20/2024"
      /(\w{3}\s+\d{1,2})/i               # "Dec 20"
    ]

    date_patterns.each do |pattern|
      match = title.match(pattern)
      next unless match

      date_str = match[1]
      # Assume current year if not specified
      date_str = "#{date_str} #{Time.current.year}" unless date_str.match?(/\d{4}/)

      begin
        parsed = Date.parse(date_str)
        # Default to 8pm for concert events
        return parsed.to_time.change(hour: 20, min: 0)
      rescue ArgumentError
        next
      end
    end

    nil
  end

  def clean_bottom_of_hill_title(title)
    # Remove date prefix from title: "Fri, Dec 20: Band Name" -> "Band Name"
    title.sub(/^\w{3},?\s+\w{3}\s+\d{1,2}:\s*/, "").strip
  end

  def extract_location_from_description(description)
    # Simple pattern to extract location from description
    # Look for patterns like "Location: ..." or "@..."
    return nil if description.blank?

    location_match = description.match(/(?:Location|Where|@):\s*([^\n<]+)/i)
    location_match ? sanitize_text(location_match[1]) : nil
  end

  def extract_categories(entry)
    categories = []

    # Extract from RSS categories
    if entry.respond_to?(:categories) && entry.categories.present?
      categories += entry.categories.map { |c| c.to_s.downcase }
    end

    # Extract from tags if available
    if entry.respond_to?(:tags) && entry.tags.present?
      categories += entry.tags.map { |t| t.to_s.downcase }
    end

    categories.uniq.first(5) # Limit to 5 categories
  end

  def sanitize_text(text)
    return nil if text.blank?
    ActionController::Base.helpers.sanitize(text.to_s, tags: []).strip
  end

  def sanitize_html(html)
    return nil if html.blank?
    # Allow basic formatting tags
    ActionController::Base.helpers.sanitize(html.to_s, tags: %w[p br strong em a], attributes: %w[href]).strip
  end

  def valid_event?(event_data)
    # Minimum requirements for a valid event
    event_data[:title].present? &&
      event_data[:start_time].present? &&
      event_data[:source_url].present?
  end
end
