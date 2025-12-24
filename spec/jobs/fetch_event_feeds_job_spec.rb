require "rails_helper"

RSpec.describe FetchEventFeedsJob, type: :job do
  describe "#perform" do
    let(:feed) { create(:event_feed) }
    let(:event_data) do
      [
        {
          title: "Test Event",
          start_time: 2.days.from_now,
          source_url: "https://example.com/event1",
          external_id: "event-1"
        }
      ]
    end

    before do
      allow_any_instance_of(RssParserService).to receive(:parse).and_return(event_data)
    end

    context "with no feed_id specified" do
      it "fetches all active feeds" do
        active_feed = create(:event_feed)
        inactive_feed = create(:event_feed, :inactive)

        expect_any_instance_of(EventSyncService).to receive(:sync).once

        described_class.perform_now
      end

      it "creates events from parsed data" do
        create(:event_feed)

        expect {
          described_class.perform_now
        }.to change(ExternalEvent, :count).by(1)
      end

      it "updates feed last_fetched_at" do
        feed = create(:event_feed)

        described_class.perform_now
        feed.reload

        expect(feed.last_fetched_at).to be_within(1.second).of(Time.current)
      end

      it "updates feed event_count" do
        feed = create(:event_feed)

        described_class.perform_now
        feed.reload

        expect(feed.event_count).to eq(1)
      end

      it "clears errors on successful fetch" do
        feed = create(:event_feed, :with_error)

        described_class.perform_now
        feed.reload

        expect(feed.last_error).to be_nil
      end

      it "archives old events after syncing" do
        create(:event_feed)
        old_event = create(:external_event, :past, start_time: 10.days.ago)

        described_class.perform_now
        old_event.reload

        expect(old_event.archived_at).to be_present
      end

      it "does not archive recent past events" do
        create(:event_feed)
        recent_event = create(:external_event, :past, start_time: 5.days.ago)

        described_class.perform_now
        recent_event.reload

        expect(recent_event.archived_at).to be_nil
      end
    end

    context "with specific feed_id" do
      it "fetches only the specified feed" do
        feed1 = create(:event_feed)
        feed2 = create(:event_feed, :funcheap)

        expect_any_instance_of(RssParserService).to receive(:parse).once.and_return(event_data)

        described_class.perform_now(feed1.id)
      end

      it "creates events for the specified feed" do
        feed = create(:event_feed)

        expect {
          described_class.perform_now(feed.id)
        }.to change { feed.external_events.count }.by(1)
      end
    end

    context "with fetch errors" do
      before do
        allow_any_instance_of(RssParserService).to receive(:parse)
          .and_raise(RssParserService::FetchError.new("Connection timeout"))
      end

      it "records the error on the feed" do
        feed = create(:event_feed)

        expect {
          described_class.perform_now
        }.to raise_error(RssParserService::FetchError)

        feed.reload
        expect(feed.last_error).to include("Connection timeout")
      end

      it "retries on FetchError" do
        feed = create(:event_feed)

        expect {
          described_class.perform_now
        }.to have_enqueued_job(described_class).on_queue("event_feeds")
      end
    end

    context "with invalid URL errors" do
      before do
        allow_any_instance_of(RssParserService).to receive(:parse)
          .and_raise(RssParserService::InvalidUrlError.new("Invalid URL"))
      end

      it "discards the job on InvalidUrlError" do
        feed = create(:event_feed)

        expect {
          described_class.perform_now
        }.not_to have_enqueued_job(described_class)
      end

      it "records the error on the feed" do
        feed = create(:event_feed)

        expect {
          described_class.perform_now rescue nil
        }

        feed.reload
        expect(feed.last_error).to include("Invalid URL")
      end
    end

    context "with parse errors" do
      before do
        allow_any_instance_of(RssParserService).to receive(:parse)
          .and_raise(RssParserService::ParseError.new("Invalid XML"))
      end

      it "records the error on the feed" do
        feed = create(:event_feed)

        expect {
          described_class.perform_now rescue nil
        }

        feed.reload
        expect(feed.last_error).to include("Invalid XML")
      end
    end

    context "with standard errors" do
      before do
        allow_any_instance_of(RssParserService).to receive(:parse)
          .and_raise(StandardError.new("Unexpected error"))
      end

      it "records the error on the feed" do
        feed = create(:event_feed)

        expect {
          described_class.perform_now rescue nil
        }

        feed.reload
        expect(feed.last_error).to include("Unexpected error")
      end
    end
  end

  describe "job configuration" do
    it "is queued on event_feeds queue" do
      expect(described_class.new.queue_name).to eq("event_feeds")
    end
  end

  describe "#sync_feed" do
    let(:feed) { create(:event_feed) }
    let(:event_data) do
      [
        {
          title: "Test Event",
          start_time: 2.days.from_now,
          source_url: "https://example.com/event1"
        }
      ]
    end

    before do
      allow_any_instance_of(RssParserService).to receive(:parse).and_return(event_data)
    end

    it "parses the feed" do
      expect_any_instance_of(RssParserService).to receive(:parse)

      described_class.new.send(:sync_feed, feed)
    end

    it "syncs the events" do
      expect_any_instance_of(EventSyncService).to receive(:sync).with(event_data)

      described_class.new.send(:sync_feed, feed)
    end

    it "logs the sync result" do
      expect(Rails.logger).to receive(:info).with(/Synced.*events for/)

      described_class.new.send(:sync_feed, feed)
    end
  end

  describe "#archive_old_events" do
    it "archives events older than 7 days" do
      old_event = create(:external_event, :past, start_time: 10.days.ago)

      described_class.new.send(:archive_old_events)
      old_event.reload

      expect(old_event.archived_at).to be_present
    end

    it "does not archive recent events" do
      recent_event = create(:external_event, :past, start_time: 5.days.ago)

      described_class.new.send(:archive_old_events)
      recent_event.reload

      expect(recent_event.archived_at).to be_nil
    end

    it "does not archive already archived events" do
      archived_event = create(:external_event, :archived, start_time: 10.days.ago)
      original_archived_at = archived_event.archived_at

      described_class.new.send(:archive_old_events)
      archived_event.reload

      expect(archived_event.archived_at).to eq(original_archived_at)
    end

    it "logs the archive count" do
      create(:external_event, :past, start_time: 10.days.ago)

      expect(Rails.logger).to receive(:info).with(/Archived.*past events/)

      described_class.new.send(:archive_old_events)
    end
  end
end
