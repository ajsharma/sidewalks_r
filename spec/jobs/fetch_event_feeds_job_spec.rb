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
          external_id: "event-1",
          raw_data: { feed_url: feed.url, title: "Test Event" }
        }
      ]
    end

    let(:sync_results) do
      {
        success: true,
        events_added: 1,
        events_updated: 0,
        events_skipped: 0,
        errors: []
      }
    end

    before do
      allow_any_instance_of(RssParserService).to receive(:parse).and_return(event_data)
      allow_any_instance_of(EventSyncService).to receive(:sync).and_return(sync_results)
    end

    context "with no feed_id specified" do
      it "fetches all active feeds" do
        active_feed = create(:event_feed)
        inactive_feed = create(:event_feed, :inactive)

        # Only active feeds should be synced
        expect(EventFeed).to receive(:active).and_call_original
        expect_any_instance_of(EventSyncService).to receive(:sync).exactly(1).times.and_return(sync_results)

        described_class.perform_now
      end

      it "creates events from parsed data" do
        create(:event_feed)

        # Remove the stub so events actually get created
        allow_any_instance_of(EventSyncService).to receive(:sync).and_call_original

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

        # Remove the stub so events actually get created
        allow_any_instance_of(EventSyncService).to receive(:sync).and_call_original

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
        feed2 = create(:event_feed, name: "Other Feed", url: "https://sf.funcheap.com/rss-date/")

        expect_any_instance_of(EventSyncService).to receive(:sync).once.and_return(sync_results)

        described_class.perform_now(feed1.id)
      end

      it "creates events for the specified feed" do
        feed = create(:event_feed)

        # Remove the stub so events actually get created
        allow_any_instance_of(EventSyncService).to receive(:sync).and_call_original

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
          perform_enqueued_jobs do
            described_class.perform_later
          end
        }.to raise_error(RssParserService::FetchError)

        # Check that retry was attempted
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs.count).to be > 0
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
          described_class.perform_now rescue RssParserService::InvalidUrlError
        }.not_to change { ActiveJob::Base.queue_adapter.enqueued_jobs.count }
      end

      it "records the error on the feed" do
        feed = create(:event_feed)

        expect {
          described_class.perform_now
        }.to raise_error(RssParserService::InvalidUrlError)

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

        # EventSyncService catches ParseError and returns results with errors
        allow_any_instance_of(EventSyncService).to receive(:sync).and_return({
          success: false,
          events_added: 0,
          events_updated: 0,
          events_skipped: 0,
          errors: ["Feed parse failed: Invalid XML"]
        })

        expect {
          described_class.perform_now
        }.not_to raise_error

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

        # EventSyncService catches StandardError and returns results with errors
        allow_any_instance_of(EventSyncService).to receive(:sync).and_return({
          success: false,
          events_added: 0,
          events_updated: 0,
          events_skipped: 0,
          errors: ["Unexpected error: Unexpected error"]
        })

        expect {
          described_class.perform_now
        }.not_to raise_error

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
          source_url: "https://example.com/event1",
          raw_data: {}
        }
      ]
    end

    let(:sync_results) do
      {
        success: true,
        events_added: 1,
        events_updated: 0,
        events_skipped: 0,
        errors: []
      }
    end

    before do
      allow_any_instance_of(RssParserService).to receive(:parse).and_return(event_data)
      allow_any_instance_of(EventSyncService).to receive(:sync).and_return(sync_results)
    end

    it "parses the feed" do
      # EventSyncService calls RssParserService internally
      expect_any_instance_of(RssParserService).to receive(:parse)

      described_class.new.send(:sync_feed, feed)
    end

    it "syncs the events" do
      expect_any_instance_of(EventSyncService).to receive(:sync)

      described_class.new.send(:sync_feed, feed)
    end

    it "logs the sync result" do
      expect(Rails.logger).to receive(:info).with(/Added 1, Updated 0, Skipped 0/)

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

      expect(Rails.logger).to receive(:info).with(/Archived 1 old events/)

      described_class.new.send(:archive_old_events)
    end
  end
end
