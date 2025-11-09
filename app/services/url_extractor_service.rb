require "nokogiri"
require "uri"
require "net/http"

# Service for extracting structured event/activity data from URLs.
# Implements SSRF protection, parses Schema.org markup, OpenGraph tags, and HTML metadata.
class UrlExtractorService
  # Raised when URL is invalid, blocked, or malformed
  class InvalidUrlError < StandardError; end
  # Raised when URL fetch fails due to network issues or HTTP errors
  class FetchError < StandardError; end

  TIMEOUT_SECONDS = 10
  MAX_REDIRECTS = 5
  MAX_CONTENT_LENGTH = 5_000_000 # 5MB

  # Blocked hosts for SSRF prevention
  BLOCKED_PATTERNS = [
    /^localhost$/i,
    /^127\./,
    /^192\.168\./,
    /^10\./,
    /^172\.(1[6-9]|2[0-9]|3[01])\./,
    /^169\.254\./,  # Link-local
    /^::1$/,        # IPv6 localhost
    /^fe80:/i,      # IPv6 link-local
    /^metadata\.google\.internal$/i  # Cloud metadata
  ].freeze

  def initialize(url)
    @url = url.strip
    @uri = parse_and_validate_url!
  end

  # Main extraction method
  # @return [Hash] extracted data with keys: structured_data, html_content, needs_ai_parsing
  def extract
    html = fetch_url_content

    # Try Schema.org and OpenGraph extraction first (fast path)
    structured_data = extract_structured_data(html)

    if sufficient_data?(structured_data)
      {
        structured_data: structured_data,
        html_content: nil,
        needs_ai_parsing: false,
        source_url: @url
      }
    else
      # Fall back to AI parsing (slow path)
      {
        structured_data: structured_data,
        html_content: html,
        needs_ai_parsing: true,
        source_url: @url
      }
    end
  end

  private

  def parse_and_validate_url!
    uri = URI.parse(@url)

    # Ensure HTTP/HTTPS
    unless %w[http https].include?(uri.scheme&.downcase)
      raise InvalidUrlError, "URL must use HTTP or HTTPS protocol"
    end

    # Validate host is present
    raise InvalidUrlError, "URL must have a valid host" unless uri.host

    # SSRF prevention - check for blocked patterns
    if BLOCKED_PATTERNS.any? { |pattern| uri.host.match?(pattern) }
      raise InvalidUrlError, "URL host is not allowed (private/internal network)"
    end

    # Check for IP addresses (basic check)
    if uri.host.match?(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)
      raise InvalidUrlError, "Direct IP addresses are not allowed"
    end

    uri
  rescue URI::InvalidURIError => e
    raise InvalidUrlError, "Invalid URL format: #{e.message}"
  end

  def fetch_url_content(redirect_count = 0)
    raise FetchError, "Too many redirects" if redirect_count >= MAX_REDIRECTS

    response = make_http_request

    case response
    when Net::HTTPSuccess
      validate_content_length(response)
      response.body
    when Net::HTTPRedirection
      location = response["location"]
      raise FetchError, "Redirect with no location" unless location

      # Validate redirect URL
      @uri = parse_and_validate_url_from_redirect(location)
      fetch_url_content(redirect_count + 1)
    else
      raise FetchError, "HTTP error: #{response.code} #{response.message}"
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise FetchError, "Request timed out: #{e.message}"
  rescue SocketError => e
    raise FetchError, "Could not resolve host: #{e.message}"
  rescue StandardError => e
    raise FetchError, "Failed to fetch URL: #{e.message}"
  end

  def make_http_request
    Net::HTTP.start(
      @uri.host,
      @uri.port,
      use_ssl: @uri.scheme == "https",
      open_timeout: TIMEOUT_SECONDS,
      read_timeout: TIMEOUT_SECONDS
    ) do |http|
      request = Net::HTTP::Get.new(@uri.request_uri)
      request["User-Agent"] = "SidewalksBot/1.0 (Activity Planning Assistant)"
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
    # Handle relative redirects
    redirect_uri = location.start_with?("http") ? URI.parse(location) : @uri + location

    # Re-validate the redirect URL for SSRF
    if BLOCKED_PATTERNS.any? { |pattern| redirect_uri.host.match?(pattern) }
      raise InvalidUrlError, "Redirect to blocked host"
    end

    redirect_uri
  end

  def extract_structured_data(html)
    doc = Nokogiri::HTML(html)
    data = {}

    # Extract Schema.org JSON-LD
    schema_org = extract_schema_org(doc)
    data.merge!(schema_org) if schema_org.present?

    # Extract OpenGraph metadata
    open_graph = extract_open_graph(doc)
    data.merge!(open_graph) if open_graph.present?

    # Extract Twitter Card metadata
    twitter = extract_twitter_cards(doc)
    data.merge!(twitter) if twitter.present?

    # Extract basic HTML metadata
    basic_meta = extract_basic_metadata(doc)
    data.merge!(basic_meta) if basic_meta.present?

    data
  rescue StandardError => e
    Rails.logger.error("Failed to parse HTML: #{e.message}")
    {}
  end

  def extract_schema_org(doc)
    data = {}

    doc.css('script[type="application/ld+json"]').each do |script|
      begin
        json_ld = JSON.parse(script.content)

        # Handle both single objects and arrays
        json_ld = [ json_ld ] unless json_ld.is_a?(Array)

        json_ld.each do |item|
          next unless item.is_a?(Hash)

          type = item["@type"]
          next unless %w[Event SocialEvent BusinessEvent].include?(type)

          data[:name] ||= item["name"]
          data[:description] ||= item["description"]
          data[:start_date] ||= item["startDate"]
          data[:end_date] ||= item["endDate"]
          data[:location] ||= extract_location(item["location"])
          data[:image_url] ||= extract_image(item["image"])
          data[:organizer] ||= extract_organizer(item["organizer"])
          data[:price] ||= extract_price(item["offers"])
        end
      rescue JSON::ParserError
        next
      end
    end

    data.compact
  end

  def extract_open_graph(doc)
    data = {}

    doc.css('meta[property^="og:"]').each do |meta|
      property = meta["property"]
      content = meta["content"]
      next unless content.present?

      case property
      when "og:title"
        data[:name] ||= content
      when "og:description"
        data[:description] ||= content
      when "og:image"
        data[:image_url] ||= content
      when "og:url"
        data[:canonical_url] ||= content
      end
    end

    data.compact
  end

  def extract_twitter_cards(doc)
    data = {}

    doc.css('meta[name^="twitter:"]').each do |meta|
      name = meta["name"]
      content = meta["content"]
      next unless content.present?

      case name
      when "twitter:title"
        data[:name] ||= content
      when "twitter:description"
        data[:description] ||= content
      when "twitter:image"
        data[:image_url] ||= content
      end
    end

    data.compact
  end

  def extract_basic_metadata(doc)
    data = {}

    # Title
    data[:name] ||= doc.at_css("title")&.text&.strip

    # Meta description
    meta_desc = doc.at_css('meta[name="description"]')
    data[:description] ||= meta_desc["content"]&.strip if meta_desc

    # Canonical URL
    canonical = doc.at_css('link[rel="canonical"]')
    data[:canonical_url] ||= canonical["href"] if canonical

    data.compact
  end

  def extract_location(location_data)
    return nil unless location_data.is_a?(Hash)

    if location_data["name"]
      location_data["name"]
    elsif location_data["address"]
      format_address(location_data["address"])
    end
  end

  def format_address(address)
    return address unless address.is_a?(Hash)

    [
      address["streetAddress"],
      address["addressLocality"],
      address["addressRegion"],
      address["postalCode"]
    ].compact.join(", ")
  end

  def extract_image(image_data)
    return nil unless image_data

    case image_data
    when String
      image_data
    when Hash
      image_data["url"]
    when Array
      image_data.first.is_a?(String) ? image_data.first : image_data.first["url"]
    end
  end

  def extract_organizer(organizer_data)
    return nil unless organizer_data.is_a?(Hash)

    organizer_data["name"]
  end

  def extract_price(offers_data)
    return nil unless offers_data

    offers = offers_data.is_a?(Array) ? offers_data.first : offers_data
    return nil unless offers.is_a?(Hash)

    price = offers["price"]
    currency = offers["priceCurrency"] || "USD"

    return nil unless price

    "#{price} #{currency}"
  end

  def sufficient_data?(data)
    # Consider data sufficient if we have at least name and description
    data[:name].present? && data[:description].present?
  end
end
