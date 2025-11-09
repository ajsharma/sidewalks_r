require "test_helper"

class UrlExtractorServiceTest < ActiveSupport::TestCase
  test "raises InvalidUrlError for missing protocol" do
    error = assert_raises(UrlExtractorService::InvalidUrlError) do
      UrlExtractorService.new("example.com")
    end

    assert_match(/must use HTTP or HTTPS/, error.message)
  end

  test "raises InvalidUrlError for localhost" do
    error = assert_raises(UrlExtractorService::InvalidUrlError) do
      UrlExtractorService.new("http://localhost/event")
    end

    assert_match(/private\/internal network/, error.message)
  end

  test "raises InvalidUrlError for 127.0.0.1" do
    error = assert_raises(UrlExtractorService::InvalidUrlError) do
      UrlExtractorService.new("http://127.0.0.1/event")
    end

    assert_match(/private\/internal network/, error.message)
  end

  test "raises InvalidUrlError for private IP 192.168.x.x" do
    error = assert_raises(UrlExtractorService::InvalidUrlError) do
      UrlExtractorService.new("http://192.168.1.1/event")
    end

    assert_match(/private\/internal network/, error.message)
  end

  test "raises InvalidUrlError for private IP 10.x.x.x" do
    error = assert_raises(UrlExtractorService::InvalidUrlError) do
      UrlExtractorService.new("http://10.0.0.1/event")
    end

    assert_match(/private\/internal network/, error.message)
  end

  test "raises InvalidUrlError for direct IP addresses" do
    error = assert_raises(UrlExtractorService::InvalidUrlError) do
      UrlExtractorService.new("http://8.8.8.8/event")
    end

    assert_match(/Direct IP addresses are not allowed/, error.message)
  end

  test "raises InvalidUrlError for cloud metadata endpoint" do
    error = assert_raises(UrlExtractorService::InvalidUrlError) do
      UrlExtractorService.new("http://metadata.google.internal/computeMetadata/v1/")
    end

    assert_match(/private\/internal network/, error.message)
  end

  test "accepts valid https URL" do
    service = UrlExtractorService.new("https://example.com/event")
    assert_not_nil service
  end

  test "extract returns structured data from Schema.org JSON-LD" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@type": "Event",
              "name": "Summer Concert",
              "description": "Outdoor music festival",
              "startDate": "2025-07-15",
              "location": {
                "name": "Central Park"
              },
              "image": "https://example.com/concert.jpg",
              "organizer": {
                "name": "Music Events Inc"
              },
              "offers": {
                "price": "25.00",
                "priceCurrency": "USD"
              }
            }
          </script>
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/event")
      .to_return(status: 200, body: html)

    service = UrlExtractorService.new("https://example.com/event")
    result = service.extract

    assert_equal "Summer Concert", result[:structured_data][:name]
    assert_equal "Outdoor music festival", result[:structured_data][:description]
    assert_equal "Central Park", result[:structured_data][:location]
    assert_equal "https://example.com/concert.jpg", result[:structured_data][:image_url]
    assert_equal "Music Events Inc", result[:structured_data][:organizer]
    assert_equal "25.00 USD", result[:structured_data][:price]
    assert_not result[:needs_ai_parsing]
  end

  test "extract returns structured data from OpenGraph metadata" do
    html = <<~HTML
      <html>
        <head>
          <meta property="og:title" content="Tech Conference 2025">
          <meta property="og:description" content="Annual technology conference">
          <meta property="og:image" content="https://example.com/conf.jpg">
          <meta property="og:url" content="https://example.com/event">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/event")
      .to_return(status: 200, body: html)

    service = UrlExtractorService.new("https://example.com/event")
    result = service.extract

    assert_equal "Tech Conference 2025", result[:structured_data][:name]
    assert_equal "Annual technology conference", result[:structured_data][:description]
    assert_equal "https://example.com/conf.jpg", result[:structured_data][:image_url]
  end

  test "extract returns structured data from Twitter Cards" do
    html = <<~HTML
      <html>
        <head>
          <meta name="twitter:title" content="Workshop Event">
          <meta name="twitter:description" content="Learn new skills">
          <meta name="twitter:image" content="https://example.com/workshop.jpg">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/event")
      .to_return(status: 200, body: html)

    service = UrlExtractorService.new("https://example.com/event")
    result = service.extract

    assert_equal "Workshop Event", result[:structured_data][:name]
    assert_equal "Learn new skills", result[:structured_data][:description]
    assert_equal "https://example.com/workshop.jpg", result[:structured_data][:image_url]
  end

  test "extract falls back to basic HTML metadata" do
    html = <<~HTML
      <html>
        <head>
          <title>Basic Event Page</title>
          <meta name="description" content="Simple event description">
          <link rel="canonical" href="https://example.com/event">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/event")
      .to_return(status: 200, body: html)

    service = UrlExtractorService.new("https://example.com/event")
    result = service.extract

    assert_equal "Basic Event Page", result[:structured_data][:name]
    assert_equal "Simple event description", result[:structured_data][:description]
    assert_equal "https://example.com/event", result[:structured_data][:canonical_url]
  end

  test "extract indicates AI parsing needed when insufficient data" do
    html = <<~HTML
      <html>
        <head>
          <title>Event</title>
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/event")
      .to_return(status: 200, body: html)

    service = UrlExtractorService.new("https://example.com/event")
    result = service.extract

    assert result[:needs_ai_parsing]
    assert_not_nil result[:html_content]
  end

  test "extract handles HTTP redirects" do
    stub_request(:get, "http://example.com/event")
      .to_return(status: 301, headers: { "Location" => "https://example.com/event" })

    stub_request(:get, "https://example.com/event")
      .to_return(status: 200, body: "<html><head><title>Event</title></head></html>")

    service = UrlExtractorService.new("http://example.com/event")
    result = service.extract

    assert_not_nil result
  end

  test "extract raises FetchError for too many redirects" do
    stub_request(:get, "https://example.com/event1")
      .to_return(status: 301, headers: { "Location" => "https://example.com/event2" })
    stub_request(:get, "https://example.com/event2")
      .to_return(status: 301, headers: { "Location" => "https://example.com/event3" })
    stub_request(:get, "https://example.com/event3")
      .to_return(status: 301, headers: { "Location" => "https://example.com/event4" })
    stub_request(:get, "https://example.com/event4")
      .to_return(status: 301, headers: { "Location" => "https://example.com/event5" })
    stub_request(:get, "https://example.com/event5")
      .to_return(status: 301, headers: { "Location" => "https://example.com/event6" })

    service = UrlExtractorService.new("https://example.com/event1")

    error = assert_raises(UrlExtractorService::FetchError) do
      service.extract
    end

    assert_match(/Too many redirects/, error.message)
  end

  test "extract raises FetchError for HTTP errors" do
    stub_request(:get, "https://example.com/event")
      .to_return(status: 404)

    service = UrlExtractorService.new("https://example.com/event")

    error = assert_raises(UrlExtractorService::FetchError) do
      service.extract
    end

    assert_match(/HTTP error: 404/, error.message)
  end

  test "extract raises FetchError for timeout" do
    stub_request(:get, "https://example.com/event")
      .to_timeout

    service = UrlExtractorService.new("https://example.com/event")

    error = assert_raises(UrlExtractorService::FetchError) do
      service.extract
    end

    assert_match(/timed out/, error.message)
  end

  test "extract raises FetchError for content too large" do
    stub_request(:get, "https://example.com/event")
      .to_return(
        status: 200,
        headers: { "Content-Length" => "10000000" },
        body: ""
      )

    service = UrlExtractorService.new("https://example.com/event")

    error = assert_raises(UrlExtractorService::FetchError) do
      service.extract
    end

    assert_match(/Content too large/, error.message)
  end

  test "extract prevents SSRF on redirect to private network" do
    stub_request(:get, "https://example.com/event")
      .to_return(status: 301, headers: { "Location" => "http://192.168.1.1/admin" })

    service = UrlExtractorService.new("https://example.com/event")

    error = assert_raises(UrlExtractorService::FetchError) do
      service.extract
    end

    assert_match(/Redirect to blocked host/, error.message)
  end

  test "extract handles malformed JSON-LD gracefully" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            { invalid json }
          </script>
          <title>Event</title>
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/event")
      .to_return(status: 200, body: html)

    service = UrlExtractorService.new("https://example.com/event")
    result = service.extract

    # Should not crash, should fall back to other metadata
    assert_equal "Event", result[:structured_data][:name]
  end
end
