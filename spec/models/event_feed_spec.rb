require "rails_helper"

RSpec.describe EventFeed, type: :model do
  describe "associations" do
    it "has many external_events with dependent destroy" do
      feed = create(:event_feed)
      event = create(:external_event, event_feed: feed)

      expect(feed.external_events).to include(event)

      expect { feed.destroy }.to change(ExternalEvent, :count).by(-1)
    end
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:url) }

    it "validates URL is from allowed list" do
      feed = build(:event_feed, url: "https://malicious-site.com/feed")
      expect(feed).not_to be_valid
      expect(feed.errors[:url]).to include("must be from an allowed feed source")
    end

    it "allows Bottom of the Hill URL" do
      feed = build(:event_feed, url: "https://www.bottomofthehill.com/RSS.xml")
      expect(feed).to be_valid
    end

    it "allows FunCheap SF URL" do
      feed = build(:event_feed, url: "https://sf.funcheap.com/rss-date/")
      expect(feed).to be_valid
    end

    it "allows Eddie's List URL" do
      feed = build(:event_feed, url: "https://www.eddies-list.com/feed")
      expect(feed).to be_valid
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active feeds" do
        active_feed = create(:event_feed)
        inactive_feed = create(:event_feed, :inactive)

        expect(EventFeed.active).to include(active_feed)
        expect(EventFeed.active).not_to include(inactive_feed)
      end
    end

    describe ".needs_refresh" do
      it "returns feeds never fetched" do
        never_fetched = create(:event_feed)
        expect(EventFeed.needs_refresh).to include(never_fetched)
      end

      it "returns feeds fetched more than 6 hours ago by default" do
        stale_feed = create(:event_feed, :stale)
        expect(EventFeed.needs_refresh).to include(stale_feed)
      end

      it "does not return recently fetched feeds" do
        recent_feed = create(:event_feed, :recently_fetched)
        expect(EventFeed.needs_refresh).not_to include(recent_feed)
      end

      it "accepts custom hours parameter" do
        feed_1_hour_ago = create(:event_feed, last_fetched_at: 1.hour.ago)
        feed_3_hours_ago = create(:event_feed, last_fetched_at: 3.hours.ago)

        expect(EventFeed.needs_refresh(2)).to include(feed_3_hours_ago)
        expect(EventFeed.needs_refresh(2)).not_to include(feed_1_hour_ago)
      end
    end
  end

  describe "#mark_fetched!" do
    it "updates last_fetched_at" do
      feed = create(:event_feed)
      feed.mark_fetched!

      expect(feed.last_fetched_at).to be_within(1.second).of(Time.current)
    end

    it "updates event_count when provided" do
      feed = create(:event_feed)
      feed.mark_fetched!(count: 42)

      expect(feed.event_count).to eq(42)
    end

    it "sets error when provided" do
      feed = create(:event_feed)
      feed.mark_fetched!(error: "Connection timeout")

      expect(feed.last_error).to eq("Connection timeout")
    end

    it "clears error when nil provided" do
      feed = create(:event_feed, :with_error)
      feed.mark_fetched!(error: nil)

      expect(feed.last_error).to be_nil
    end
  end

  describe "#clear_error!" do
    it "clears last_error" do
      feed = create(:event_feed, :with_error)
      feed.clear_error!

      expect(feed.last_error).to be_nil
    end
  end

  describe "#active?" do
    it "returns true for active feeds" do
      feed = create(:event_feed)
      expect(feed.active?).to be true
    end

    it "returns false for inactive feeds" do
      feed = create(:event_feed, :inactive)
      expect(feed.active?).to be false
    end
  end

  describe "#stale?" do
    it "returns true for never fetched feeds" do
      feed = create(:event_feed)
      expect(feed.stale?).to be true
    end

    it "returns true for feeds fetched more than 6 hours ago" do
      feed = create(:event_feed, :stale)
      expect(feed.stale?).to be true
    end

    it "returns false for recently fetched feeds" do
      feed = create(:event_feed, :recently_fetched)
      expect(feed.stale?).to be false
    end

    it "accepts custom hours parameter" do
      feed = create(:event_feed, last_fetched_at: 3.hours.ago)
      expect(feed.stale?(2)).to be true
      expect(feed.stale?(4)).to be false
    end
  end
end
