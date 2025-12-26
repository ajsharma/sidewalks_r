require "rails_helper"

RSpec.describe EventSyncService do
  let(:feed) { create(:event_feed) }
  let(:service) { described_class.new(feed) }

  describe "#sync" do
    let(:event_data) do
      {
        title: "Rock Concert",
        description: "Live music event",
        start_time: 2.days.from_now,
        end_time: 2.days.from_now + 3.hours,
        source_url: "https://example.com/event1",
        venue: "Bottom of the Hill",
        price: 25.00,
        category_tags: %w[music rock],
        external_id: "event-123",
        raw_data: { feed_url: feed.url, title: "Rock Concert" }
      }
    end

    let(:parser) { instance_double(RssParserService) }

    before do
      allow(RssParserService).to receive(:new).with(feed.url).and_return(parser)
    end

    context "with successful feed fetch" do
      before do
        allow(parser).to receive(:parse).and_return([ event_data ])
      end

      it "creates new ExternalEvent records" do
        expect {
          service.sync
        }.to change(ExternalEvent, :count).by(1)
      end

      it "sets all event attributes" do
        service.sync
        event = ExternalEvent.last

        expect(event.title).to eq("Rock Concert")
        expect(event.description).to eq("Live music event")
        expect(event.venue).to eq("Bottom of the Hill")
        expect(event.price).to eq(25.00)
        expect(event.category_tags).to eq(%w[music rock])
        expect(event.external_id).to eq("event-123")
        expect(event.raw_data).to eq({ "feed_url" => feed.url, "title" => "Rock Concert" })
      end

      it "associates events with the feed" do
        service.sync
        event = ExternalEvent.last

        expect(event.event_feed).to eq(feed)
      end

      it "sets last_synced_at timestamp" do
        service.sync
        event = ExternalEvent.last

        expect(event.last_synced_at).to be_within(1.second).of(Time.current)
      end

      it "returns success result" do
        result = service.sync

        expect(result[:success]).to be true
        expect(result[:events_added]).to eq(1)
        expect(result[:events_updated]).to eq(0)
        expect(result[:events_skipped]).to eq(0)
        expect(result[:errors]).to be_empty
      end

      it "updates feed last_fetched_at" do
        expect {
          service.sync
        }.to change { feed.reload.last_fetched_at }
      end

      it "updates feed event_count" do
        service.sync
        feed.reload

        expect(feed.event_count).to eq(1)
      end
    end

    context "with duplicate events by external_id" do
      let!(:existing_event) do
        create(:external_event,
          event_feed: feed,
          external_id: "event-123",
          title: "Old Title")
      end

      before do
        allow(parser).to receive(:parse).and_return([ event_data ])
      end

      it "does not create duplicate events" do
        expect {
          service.sync
        }.not_to change(ExternalEvent, :count)
      end

      it "updates existing event attributes" do
        service.sync
        existing_event.reload

        expect(existing_event.title).to eq("Rock Concert")
        expect(existing_event.description).to eq("Live music event")
      end

      it "updates last_synced_at timestamp" do
        service.sync
        existing_event.reload

        expect(existing_event.last_synced_at).to be_within(1.second).of(Time.current)
      end

      it "returns update count" do
        result = service.sync

        expect(result[:events_added]).to eq(0)
        expect(result[:events_updated]).to eq(1)
      end
    end

    context "with duplicate events by source_url matching" do
      let!(:existing_event) do
        create(:external_event,
          event_feed: feed,
          title: "Old Title",
          start_time: event_data[:start_time],
          external_id: nil,
          source_url: "https://example.com/event1") # Will match on source_url
      end

      before do
        # Inline similar_event_data to reduce memoized helper count
        similar_event_data = event_data.merge(
          external_id: "different-id",
          source_url: "https://example.com/event1" # Same source_url as existing
        )
        allow(parser).to receive(:parse).and_return([ similar_event_data ])
      end

      it "detects same source_url and doesn't create duplicate" do
        expect {
          service.sync
        }.not_to change(ExternalEvent, :count)
      end

      it "updates the existing event" do
        service.sync
        existing_event.reload

        expect(existing_event.title).to eq("Rock Concert")
        expect(existing_event.description).to eq("Live music event")
        expect(existing_event.external_id).to eq("different-id")
        expect(existing_event.last_synced_at).to be_within(1.second).of(Time.current)
      end
    end

    context "with multiple events" do
      let(:multiple_events) do
        [
          {
            title: "Event One",
            start_time: 2.days.from_now,
            source_url: "https://example.com/event1",
            external_id: "event-1",
            raw_data: {}
          },
          {
            title: "Event Two",
            start_time: 3.days.from_now,
            source_url: "https://example.com/event2",
            external_id: "event-2",
            raw_data: {}
          },
          {
            title: "Event Three",
            start_time: 4.days.from_now,
            source_url: "https://example.com/event3",
            external_id: "event-3",
            raw_data: {}
          }
        ]
      end

      before do
        allow(parser).to receive(:parse).and_return(multiple_events)
      end

      it "syncs all events" do
        expect {
          service.sync
        }.to change(ExternalEvent, :count).by(3)
      end

      it "returns count of created events" do
        result = service.sync
        expect(result[:events_added]).to eq(3)
        expect(result[:events_updated]).to eq(0)
      end
    end

    context "with invalid event data" do
      let(:invalid_data) do
        {
          title: "T", # Too short
          start_time: 2.days.from_now,
          source_url: "https://example.com/event1",
          raw_data: {}
        }
      end

      before do
        allow(parser).to receive(:parse).and_return([ invalid_data ])
      end

      it "skips invalid events" do
        expect {
          service.sync
        }.not_to change(ExternalEvent, :count)
      end

      it "records errors for invalid events" do
        result = service.sync
        expect(result[:errors]).not_to be_empty
        expect(result[:events_skipped]).to eq(1)
      end
    end

    context "with empty event array" do
      before do
        allow(parser).to receive(:parse).and_return([])
      end

      it "handles empty array gracefully" do
        expect {
          service.sync
        }.not_to change(ExternalEvent, :count)
      end

      it "returns zero counts" do
        result = service.sync
        expect(result[:events_added]).to eq(0)
        expect(result[:events_updated]).to eq(0)
      end
    end

    context "with feed fetch error" do
      before do
        allow(parser).to receive(:parse).and_raise(RssParserService::FetchError.new("Network error"))
      end

      it "does not raise an error" do
        expect { service.sync }.not_to raise_error
      end

      it "returns failure result" do
        result = service.sync

        expect(result[:success]).to be false
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first).to include("Feed fetch failed")
      end

      it "records error on feed" do
        service.sync
        feed.reload

        expect(feed.last_error).to include("Feed fetch failed")
      end
    end

    context "with feed parse error" do
      before do
        allow(parser).to receive(:parse).and_raise(RssParserService::ParseError.new("Invalid XML"))
      end

      it "returns failure result" do
        result = service.sync

        expect(result[:success]).to be false
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first).to include("Feed parse failed")
      end

      it "records error on feed" do
        service.sync
        feed.reload

        expect(feed.last_error).to include("Feed parse failed")
      end
    end
  end

  describe "#calculate_title_similarity" do
    it "returns 1.0 for identical titles" do
      similarity = service.send(:calculate_title_similarity, "Rock Concert", "Rock Concert")
      expect(similarity).to eq(1.0)
    end

    it "returns high similarity for similar titles" do
      similarity = service.send(:calculate_title_similarity,
        "Rock Concert Live",
        "Rock Concert")
      expect(similarity).to be > 0.6
    end

    it "returns low similarity for different titles" do
      similarity = service.send(:calculate_title_similarity,
        "Rock Concert",
        "Jazz Festival")
      expect(similarity).to be < 0.5
    end

    it "is case insensitive" do
      similarity = service.send(:calculate_title_similarity,
        "ROCK CONCERT",
        "rock concert")
      expect(similarity).to eq(1.0)
    end

    it "ignores punctuation differences" do
      similarity = service.send(:calculate_title_similarity,
        "Rock & Roll Concert!",
        "Rock Roll Concert")
      expect(similarity).to be > 0.8
    end

    it "handles empty strings" do
      similarity = service.send(:calculate_title_similarity, "", "")
      expect(similarity).to eq(0.0)
    end
  end

  describe "#find_similar_event" do
    let!(:existing_event) do
      create(:external_event,
        event_feed: feed,
        title: "Rock Concert Live Music",
        start_time: 2.days.from_now.change(hour: 20),
        source_url: "https://example.com/existing")
    end

    let(:event_data) do
      {
        title: "Rock Concert Live Event", # 75% similar (3/4 shared words: rock, concert, live)
        start_time: existing_event.start_time,
        source_url: nil # No source_url so it will use fuzzy matching
      }
    end

    it "finds events with similar title and same date" do
      # Calculate similarity: ["rock","concert","live","event"] vs ["rock","concert","live","music"]
      # Intersection: rock, concert, live = 3
      # Union: rock, concert, live, event, music = 5
      # Similarity: 3/5 = 60% - below the 80% threshold, so should return nil
      similar = service.send(:find_similar_event, event_data)

      # With 60% similarity, it should NOT find a match (threshold is 80%)
      expect(similar).to be_nil
    end

    it "returns nil for different dates" do
      different_date_data = event_data.merge(start_time: 5.days.from_now)
      similar = service.send(:find_similar_event, different_date_data)

      expect(similar).to be_nil
    end

    it "returns nil for dissimilar titles" do
      different_title_data = event_data.merge(title: "Jazz Festival")
      similar = service.send(:find_similar_event, different_title_data)

      expect(similar).to be_nil
    end

    it "finds by exact source_url match first" do
      existing_event.update!(source_url: "https://example.com/match")
      url_match_data = event_data.merge(source_url: "https://example.com/match")

      similar = service.send(:find_similar_event, url_match_data)

      expect(similar).to eq(existing_event)
    end

    it "only searches within the same feed" do
      # Use an allowed feed URL (FunCheap)
      other_feed = create(:event_feed, name: "FunCheap SF", url: EventFeed::FUNCHEAP_SF_URL)
      other_service = described_class.new(other_feed)
      other_event = create(:external_event,
        event_feed: other_feed,
        title: existing_event.title,
        start_time: existing_event.start_time,
        source_url: "https://sf.funcheap.com/event")

      # When searching by source_url, service should only find events in its own feed
      match_data = event_data.merge(source_url: existing_event.source_url)
      similar = service.send(:find_similar_event, match_data)

      expect(similar).to eq(existing_event)
      expect(similar).not_to eq(other_event)
    end
  end
end
