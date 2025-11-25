require "rails_helper"

RSpec.describe UrlExtractorService, type: :service do
  it "raises InvalidUrlError for missing protocol" do
    expect {
      UrlExtractorService.new("example.com")
    }.to raise_error(UrlExtractorService::InvalidUrlError, /must use HTTP or HTTPS/)
  end

  it "raises InvalidUrlError for localhost" do
    expect {
      UrlExtractorService.new("http://localhost/event")
    }.to raise_error(UrlExtractorService::InvalidUrlError, /private\/internal network/)
  end

  it "raises InvalidUrlError for 127.0.0.1" do
    expect {
      UrlExtractorService.new("http://127.0.0.1/event")
    }.to raise_error(UrlExtractorService::InvalidUrlError, /private\/internal network/)
  end

  it "raises InvalidUrlError for private IP 192.168.x.x" do
    expect {
      UrlExtractorService.new("http://192.168.1.1/event")
    }.to raise_error(UrlExtractorService::InvalidUrlError, /private\/internal network/)
  end

  it "raises InvalidUrlError for private IP 10.x.x.x" do
    expect {
      UrlExtractorService.new("http://10.0.0.1/event")
    }.to raise_error(UrlExtractorService::InvalidUrlError, /private\/internal network/)
  end

  it "raises InvalidUrlError for direct IP addresses" do
    expect {
      UrlExtractorService.new("http://8.8.8.8/event")
    }.to raise_error(UrlExtractorService::InvalidUrlError, /Direct IP addresses are not allowed/)
  end

  it "raises InvalidUrlError for cloud metadata endpoint" do
    expect {
      UrlExtractorService.new("http://metadata.google.internal/computeMetadata/v1/")
    }.to raise_error(UrlExtractorService::InvalidUrlError, /private\/internal network/)
  end

  it "accepts valid https URL" do
    service = UrlExtractorService.new("https://example.com/event")
    expect(service).not_to be_nil
  end

  it "extract returns structured data from Schema.org JSON-LD" do
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

    expect(result[:structured_data][:name]).to eq "Summer Concert"
    expect(result[:structured_data][:description]).to eq "Outdoor music festival"
    expect(result[:structured_data][:location]).to eq "Central Park"
    expect(result[:structured_data][:image_url]).to eq "https://example.com/concert.jpg"
    expect(result[:structured_data][:organizer]).to eq "Music Events Inc"
    expect(result[:structured_data][:price]).to eq "25.00 USD"
    expect(result[:needs_ai_parsing]).to be false
  end

  it "extract returns structured data from OpenGraph metadata" do
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

    expect(result[:structured_data][:name]).to eq "Tech Conference 2025"
    expect(result[:structured_data][:description]).to eq "Annual technology conference"
    expect(result[:structured_data][:image_url]).to eq "https://example.com/conf.jpg"
  end

  it "extract returns structured data from Twitter Cards" do
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

    expect(result[:structured_data][:name]).to eq "Workshop Event"
    expect(result[:structured_data][:description]).to eq "Learn new skills"
    expect(result[:structured_data][:image_url]).to eq "https://example.com/workshop.jpg"
  end

  it "extract falls back to basic HTML metadata" do
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

    expect(result[:structured_data][:name]).to eq "Basic Event Page"
    expect(result[:structured_data][:description]).to eq "Simple event description"
    expect(result[:structured_data][:canonical_url]).to eq "https://example.com/event"
  end

  it "extract indicates AI parsing needed when insufficient data" do
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

    expect(result[:needs_ai_parsing]).to be true
    expect(result[:html_content]).not_to be_nil
  end

  it "extract handles HTTP redirects" do
    stub_request(:get, "http://example.com/event")
      .to_return(status: 301, headers: { "Location" => "https://example.com/event" })

    stub_request(:get, "https://example.com/event")
      .to_return(status: 200, body: "<html><head><title>Event</title></head></html>")

    service = UrlExtractorService.new("http://example.com/event")
    result = service.extract

    expect(result).not_to be_nil
  end

  it "extract raises FetchError for too many redirects" do
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

    expect {
      service.extract
    }.to raise_error(UrlExtractorService::FetchError, /Too many redirects/)
  end

  it "extract raises FetchError for HTTP errors" do
    stub_request(:get, "https://example.com/event")
      .to_return(status: 404)

    service = UrlExtractorService.new("https://example.com/event")

    expect {
      service.extract
    }.to raise_error(UrlExtractorService::FetchError, /HTTP error: 404/)
  end

  it "extract raises FetchError for timeout" do
    stub_request(:get, "https://example.com/event")
      .to_timeout

    service = UrlExtractorService.new("https://example.com/event")

    expect {
      service.extract
    }.to raise_error(UrlExtractorService::FetchError, /timed out/)
  end

  it "extract raises FetchError for content too large" do
    stub_request(:get, "https://example.com/event")
      .to_return(
        status: 200,
        headers: { "Content-Length" => "10000000" },
        body: ""
      )

    service = UrlExtractorService.new("https://example.com/event")

    expect {
      service.extract
    }.to raise_error(UrlExtractorService::FetchError, /Content too large/)
  end

  it "extract prevents SSRF on redirect to private network" do
    stub_request(:get, "https://example.com/event")
      .to_return(status: 301, headers: { "Location" => "http://192.168.1.1/admin" })

    service = UrlExtractorService.new("https://example.com/event")

    expect {
      service.extract
    }.to raise_error(UrlExtractorService::FetchError, /Redirect to blocked host/)
  end

  it "extract handles malformed JSON-LD gracefully" do
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
    expect(result[:structured_data][:name]).to eq "Event"
  end
end
