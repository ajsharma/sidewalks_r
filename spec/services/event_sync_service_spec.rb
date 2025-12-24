require "rails_helper"

RSpec.describe EventSyncService do
  let(:feed) { create(:event_feed) }
  let(:service) { described_class.new(feed) }

  describe "#sync" do
    let(:event_data) do
      [
        {
          title: "Rock Concert",
          description: "Live music event",
          start_time: 2.days.from_now,
          end_time: 2.days.from_now + 3.hours,
          source_url: "https://example.com/event1",
          venue: "Bottom of the Hill",
          price: 25.00,
          category_tags: %w[music rock],
          external_id: "event-123"
        }
      ]
    end

    context "with new events" do
      it "creates new ExternalEvent records" do
        expect {
          service.sync(event_data)
        }.to change(ExternalEvent, :count).by(1)
      end

      it "sets all event attributes" do
        service.sync(event_data)
        event = ExternalEvent.last

        expect(event.title).to eq("Rock Concert")
        expect(event.description).to eq("Live music event")
        expect(event.venue).to eq("Bottom of the Hill")
        expect(event.price).to eq(25.00)
        expect(event.category_tags).to eq(%w[music rock])
        expect(event.external_id).to eq("event-123")
      end

      it "associates events with the feed" do
        service.sync(event_data)
        event = ExternalEvent.last

        expect(event.event_feed).to eq(feed)
      end

      it "sets last_synced_at timestamp" do
        service.sync(event_data)
        event = ExternalEvent.last

        expect(event.last_synced_at).to be_within(1.second).of(Time.current)
      end
    end

    context "with duplicate events by external_id" do
      let!(:existing_event) do
        create(:external_event,
          event_feed: feed,
          external_id: "event-123",
          title: "Old Title")
      end

      it "does not create duplicate events" do
        expect {
          service.sync(event_data)
        }.not_to change(ExternalEvent, :count)
      end

      it "updates existing event attributes" do
        service.sync(event_data)
        existing_event.reload

        expect(existing_event.title).to eq("Rock Concert")
        expect(existing_event.description).to eq("Live music event")
      end

      it "updates last_synced_at timestamp" do
        service.sync(event_data)
        existing_event.reload

        expect(existing_event.last_synced_at).to be_within(1.second).of(Time.current)
      end
    end

    context "with duplicate events by fuzzy matching" do
      let!(:existing_event) do
        create(:external_event,
          event_feed: feed,
          title: "Rock Concert Live",
          start_time: event_data.first[:start_time],
          external_id: nil)
      end

      it "detects similar titles with same start time" do
        expect {
          service.sync(event_data)
        }.not_to change(ExternalEvent, :count)
      end

      it "updates the existing event" do
        service.sync(event_data)
        existing_event.reload

        expect(existing_event.description).to eq("Live music event")
        expect(existing_event.last_synced_at).to be_within(1.second).of(Time.current)
      end
    end

    context "with similar but different events" do
      let!(:existing_event) do
        create(:external_event,
          event_feed: feed,
          title: "Rock Concert",
          start_time: 5.days.from_now) # Different date
      end

      it "creates new event when dates differ" do
        expect {
          service.sync(event_data)
        }.to change(ExternalEvent, :count).by(1)
      end
    end

    context "with multiple events" do
      let(:multiple_events) do
        [
          {
            title: "Event One",
            start_time: 2.days.from_now,
            source_url: "https://example.com/event1",
            external_id: "event-1"
          },
          {
            title: "Event Two",
            start_time: 3.days.from_now,
            source_url: "https://example.com/event2",
            external_id: "event-2"
          },
          {
            title: "Event Three",
            start_time: 4.days.from_now,
            source_url: "https://example.com/event3",
            external_id: "event-3"
          }
        ]
      end

      it "syncs all events" do
        expect {
          service.sync(multiple_events)
        }.to change(ExternalEvent, :count).by(3)
      end

      it "returns count of created events" do
        result = service.sync(multiple_events)
        expect(result[:created]).to eq(3)
        expect(result[:updated]).to eq(0)
      end
    end

    context "with mix of new and existing events" do
      let!(:existing_event) do
        create(:external_event,
          event_feed: feed,
          external_id: "event-1",
          title: "Old Title")
      end

      let(:mixed_events) do
        [
          {
            title: "Updated Event",
            start_time: 2.days.from_now,
            source_url: "https://example.com/event1",
            external_id: "event-1"
          },
          {
            title: "New Event",
            start_time: 3.days.from_now,
            source_url: "https://example.com/event2",
            external_id: "event-2"
          }
        ]
      end

      it "creates new and updates existing" do
        expect {
          service.sync(mixed_events)
        }.to change(ExternalEvent, :count).by(1)

        existing_event.reload
        expect(existing_event.title).to eq("Updated Event")
      end

      it "returns accurate counts" do
        result = service.sync(mixed_events)
        expect(result[:created]).to eq(1)
        expect(result[:updated]).to eq(1)
      end
    end

    context "with invalid event data" do
      let(:invalid_data) do
        [
          {
            title: "T", # Too short
            start_time: 2.days.from_now,
            source_url: "https://example.com/event1"
          }
        ]
      end

      it "skips invalid events" do
        expect {
          service.sync(invalid_data)
        }.not_to change(ExternalEvent, :count)
      end

      it "logs errors for invalid events" do
        expect(Rails.logger).to receive(:error).with(/Failed to sync event/)
        service.sync(invalid_data)
      end
    end

    context "with empty event array" do
      it "handles empty array gracefully" do
        expect {
          service.sync([])
        }.not_to change(ExternalEvent, :count)
      end

      it "returns zero counts" do
        result = service.sync([])
        expect(result[:created]).to eq(0)
        expect(result[:updated]).to eq(0)
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
        title: "Rock Concert at Bottom of the Hill",
        start_time: 2.days.from_now.change(hour: 20))
    end

    it "finds events with similar title and same date" do
      similar = service.send(:find_similar_event,
        "Rock Concert",
        existing_event.start_time)

      expect(similar).to eq(existing_event)
    end

    it "returns nil for different dates" do
      similar = service.send(:find_similar_event,
        "Rock Concert",
        5.days.from_now)

      expect(similar).to be_nil
    end

    it "returns nil for dissimilar titles" do
      similar = service.send(:find_similar_event,
        "Jazz Festival",
        existing_event.start_time)

      expect(similar).to be_nil
    end

    it "only searches within the same feed" do
      other_feed = create(:event_feed, :funcheap)
      other_event = create(:external_event,
        event_feed: other_feed,
        title: "Rock Concert",
        start_time: existing_event.start_time)

      similar = service.send(:find_similar_event,
        "Rock Concert",
        existing_event.start_time)

      expect(similar).to eq(existing_event)
      expect(similar).not_to eq(other_event)
    end
  end
end
