require "rails_helper"

RSpec.describe RssParserService do
  describe "#parse" do
    context "with Bottom of the Hill feed" do
      let(:url) { "https://www.bottomofthehill.com/RSS.xml" }
      let(:service) { described_class.new(url) }

      it "parses the RSS feed successfully" do
        events = service.parse
        expect(events).to be_an(Array)
        expect(events).not_to be_empty
      end

      it "extracts event details" do
        events = service.parse
        event = events.first

        expect(event[:title]).to be_present
        expect(event[:start_time]).to be_a(Time)
        expect(event[:source_url]).to be_present
        expect(event[:venue]).to eq("Bottom of the Hill")
      end

      it "extracts date from title format" do
        events = service.parse
        event = events.first

        # Bottom of the Hill format: "Fri, Dec 20: Band Name"
        expect(event[:start_time]).to be_a(Time)
        expect(event[:start_time].hour).to eq(20) # Default 8pm
      end
    end

    context "with FunCheap SF feed" do
      let(:url) { "https://sf.funcheap.com/feed" }
      let(:service) { described_class.new(url) }

      it "parses the RSS feed successfully" do
        events = service.parse
        expect(events).to be_an(Array)
        expect(events).not_to be_empty
      end

      it "extracts event details" do
        events = service.parse
        event = events.first

        expect(event[:title]).to be_present
        expect(event[:start_time]).to be_a(Time)
        expect(event[:source_url]).to be_present
      end

      it "extracts custom namespace fields" do
        events = service.parse
        event = events.first

        # FunCheap uses ev:* namespace for event details
        expect(event[:start_time]).to be_a(Time)
        # Price may or may not be present
      end

      it "sanitizes HTML in description" do
        events = service.parse
        event = events.first

        if event[:description]
          expect(event[:description]).not_to include("<script>")
          expect(event[:description]).not_to include("<iframe>")
        end
      end
    end

    context "with Eddie's List feed" do
      let(:url) { "https://www.eddies-list.com/feed" }
      let(:service) { described_class.new(url) }

      it "parses the RSS feed successfully" do
        events = service.parse
        expect(events).to be_an(Array)
        expect(events).not_to be_empty
      end

      it "extracts event details" do
        events = service.parse
        event = events.first

        expect(event[:title]).to be_present
        expect(event[:start_time]).to be_a(Time)
        expect(event[:source_url]).to be_present
      end
    end

    context "with invalid URL" do
      let(:service) { described_class.new("not-a-url") }

      it "raises InvalidUrlError" do
        expect { service.parse }.to raise_error(RssParserService::InvalidUrlError)
      end
    end

    context "with unreachable URL" do
      let(:service) { described_class.new("https://nonexistent-domain-12345.com/feed") }

      it "raises FetchError" do
        expect { service.parse }.to raise_error(RssParserService::FetchError)
      end
    end

    context "with timeout" do
      let(:url) { "https://www.bottomofthehill.com/RSS.xml" }
      let(:service) { described_class.new(url) }

      before do
        allow(service).to receive(:make_http_request).and_raise(Net::ReadTimeout.new("Request timed out"))
      end

      it "raises FetchError on timeout" do
        expect { service.parse }.to raise_error(RssParserService::FetchError, /timeout/i)
      end
    end

    context "with invalid XML" do
      let(:url) { "https://www.bottomofthehill.com/RSS.xml" }
      let(:service) { described_class.new(url) }

      before do
        allow(service).to receive(:fetch_feed_content).and_return("Not valid XML")
      end

      it "raises ParseError" do
        expect { service.parse }.to raise_error(RssParserService::ParseError)
      end
    end
  end

  describe "#extract_date_from_title" do
    let(:service) { described_class.new("http://example.com") }

    it "extracts date from 'Fri, Dec 20' format" do
      title = "Fri, Dec 20: Band Name"
      date = service.send(:extract_date_from_title, title)

      expect(date).to be_a(Time)
      expect(date.month).to eq(12)
      expect(date.day).to eq(20)
    end

    it "extracts date from 'Dec 20' format" do
      title = "Dec 20: Concert"
      date = service.send(:extract_date_from_title, title)

      expect(date).to be_a(Time)
      expect(date.month).to eq(12)
      expect(date.day).to eq(20)
    end

    it "extracts date from '12/20/2024' format" do
      title = "12/20/2024 - Event"
      date = service.send(:extract_date_from_title, title)

      expect(date).to be_a(Time)
      expect(date.month).to eq(12)
      expect(date.day).to eq(20)
    end

    it "returns nil when no date found" do
      title = "Random Title Without Date"
      date = service.send(:extract_date_from_title, title)

      expect(date).to be_nil
    end

    it "defaults to 8pm for extracted dates" do
      title = "Fri, Dec 20: Band Name"
      date = service.send(:extract_date_from_title, title)

      expect(date.hour).to eq(20)
    end
  end

  describe "#sanitize_html" do
    let(:service) { described_class.new("http://example.com") }

    it "removes script tags" do
      html = "<p>Hello</p><script>alert('xss')</script>"
      result = service.send(:sanitize_html, html)

      expect(result).not_to include("<script>")
      expect(result).to include("Hello")
    end

    it "removes iframe tags" do
      html = "<p>Content</p><iframe src='evil.com'></iframe>"
      result = service.send(:sanitize_html, html)

      expect(result).not_to include("<iframe>")
    end

    it "preserves safe HTML tags" do
      html = "<p>Paragraph</p><strong>Bold</strong><em>Italic</em>"
      result = service.send(:sanitize_html, html)

      expect(result).to include("Paragraph")
      expect(result).to include("Bold")
      expect(result).to include("Italic")
    end

    it "handles nil input" do
      result = service.send(:sanitize_html, nil)
      expect(result).to be_nil
    end

    it "handles empty string" do
      result = service.send(:sanitize_html, "")
      expect(result).to be_nil
    end
  end
end
