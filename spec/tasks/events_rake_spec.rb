require "rails_helper"
require "rake"

RSpec.describe "events rake tasks" do
  before(:all) do
    Rake.application.rake_require "tasks/events"
    Rake::Task.define_task(:environment)
  end

  before do
    Rake::Task.tasks.each(&:reenable)
  end

  # Helper to capture stdout
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  describe "events:fetch" do
    let(:feed) { create(:event_feed) }
    let(:event_data) do
      [
        {
          title: "Test Event",
          start_time: 2.days.from_now,
          source_url: "https://example.com/event1",
          external_id: "event-1",
          raw_data: { feed_url: "https://www.bottomofthehill.com/RSS.xml", title: "Test Event" }
        }
      ]
    end

    before do
      allow_any_instance_of(RssParserService).to receive(:parse).and_return(event_data)
    end

    it "runs the FetchEventFeedsJob" do
      expect(FetchEventFeedsJob).to receive(:perform_now)
      Rake::Task["events:fetch"].invoke
    end

    it "creates events from feeds" do
      feed # Create feed

      expect {
        Rake::Task["events:fetch"].invoke
      }.to change(ExternalEvent, :count)
    end

    it "outputs summary information" do
      feed # Create feed

      output = capture_stdout do
        Rake::Task["events:fetch"].invoke
      end

      expect(output).to include("Fetching RSS event feeds")
      expect(output).to include("Fetch Complete!")
      expect(output).to include("Events added:")
    end
  end

  describe "events:summary" do
    let!(:feed) { create(:event_feed, :recently_fetched) }
    let!(:active_events) { create_list(:external_event, 5, :upcoming, event_feed: feed) }
    let!(:archived_events) { create_list(:external_event, 2, :archived, event_feed: feed) }

    it "displays overall statistics" do
      output = capture_stdout do
        Rake::Task["events:summary"].invoke
      end

      expect(output).to include("OVERALL STATISTICS")
      expect(output).to include("Total events:")
      expect(output).to include("Active events:")
      expect(output).to include("Upcoming events:")
    end

    it "displays feed breakdown" do
      output = capture_stdout do
        Rake::Task["events:summary"].invoke
      end

      expect(output).to include("FEED BREAKDOWN")
      expect(output).to include(feed.name)
      expect(output).to match(/Events: \d+/)
    end

    it "shows price breakdown" do
      create(:external_event, :free, :upcoming)
      create(:external_event, :paid, :upcoming)

      output = capture_stdout do
        Rake::Task["events:summary"].invoke
      end

      expect(output).to include("PRICE BREAKDOWN")
      expect(output).to include("Free events:")
      expect(output).to include("Paid events:")
    end

    it "shows weekend events count" do
      saturday = Date.current
      saturday += 1.day until saturday.saturday?
      create(:external_event, start_time: saturday.to_time)

      output = capture_stdout do
        Rake::Task["events:summary"].invoke
      end

      expect(output).to include("Weekend events:")
    end

    it "shows top categories" do
      create(:external_event, :upcoming, category_tags: %w[music rock])
      create(:external_event, :upcoming, category_tags: %w[music jazz])

      output = capture_stdout do
        Rake::Task["events:summary"].invoke
      end

      expect(output).to include("TOP CATEGORIES")
      expect(output).to include("music:")
    end
  end

  describe "events:upcoming" do
    let!(:near_event) do
      create(:external_event,
        title: "This Week Event",
        start_time: 2.days.from_now)
    end
    let!(:far_event) do
      create(:external_event,
        title: "Next Month Event",
        start_time: 30.days.from_now)
    end

    it "displays events for next 7 days by default" do
      output = capture_stdout do
        Rake::Task["events:upcoming"].invoke
      end

      expect(output).to include("UPCOMING EVENTS (Next 7 days)")
      expect(output).to include(near_event.title)
    end

    it "does not show events beyond default range" do
      output = capture_stdout do
        Rake::Task["events:upcoming"].invoke
      end

      expect(output).to include(near_event.title)
      expect(output).not_to include(far_event.title)
    end

    it "accepts custom days parameter" do
      output = capture_stdout do
        Rake::Task["events:upcoming"].invoke(60)
      end

      expect(output).to include("UPCOMING EVENTS (Next 60 days)")
      expect(output).to include(far_event.title)
    end

    it "groups events by date" do
      create(:external_event,
        title: "Event 1",
        start_time: 2.days.from_now.change(hour: 14))
      create(:external_event,
        title: "Event 2",
        start_time: 2.days.from_now.change(hour: 20))

      output = capture_stdout do
        Rake::Task["events:upcoming"].invoke
      end

      # 3 events total: near_event + Event 1 + Event 2 (all on same day)
      expect(output).to include("3 events")
    end

    it "shows price and venue information" do
      create(:external_event,
        :free,
        venue: "The Fillmore",
        start_time: 2.days.from_now,
        end_time: 2.days.from_now + 2.hours)

      output = capture_stdout do
        Rake::Task["events:upcoming"].invoke
      end

      expect(output).to include("[FREE]")
      expect(output).to include("@ The Fillmore")
    end

    it "handles no upcoming events gracefully" do
      ExternalEvent.destroy_all

      expect {
        Rake::Task["events:upcoming"].invoke
      }.to output(/No upcoming events found/).to_stdout
    end
  end

  describe "events:health" do
    let!(:healthy_feed) do
      create(:event_feed, :recently_fetched, event_count: 10)
    end

    let!(:stale_feed) do
      create(:event_feed, :stale, name: "Stale Feed")
    end

    let!(:error_feed) do
      create(:event_feed, :with_error, name: "Error Feed")
    end

    let!(:inactive_feed) do
      create(:event_feed, :inactive, name: "Inactive Feed")
    end

    it "displays feed health status" do
      expect {
        Rake::Task["events:health"].invoke
      }.to output(/FEED HEALTH STATUS/).to_stdout
    end

    it "shows healthy feed status" do
      output = capture_stdout do
        Rake::Task["events:health"].invoke
      end

      expect(output).to match(/✓.*Active/)
      expect(output).to match(/✓.*No errors/)
    end

    it "warns about stale feeds" do
      expect {
        Rake::Task["events:health"].invoke
      }.to output(/⚠️.*stale/).to_stdout
    end

    it "shows feed errors" do
      expect {
        Rake::Task["events:health"].invoke
      }.to output(/✗.*Error/).to_stdout
    end

    it "warns about inactive feeds" do
      expect {
        Rake::Task["events:health"].invoke
      }.to output(/⚠️.*INACTIVE/).to_stdout
    end

    it "shows overall health summary" do
      expect {
        Rake::Task["events:health"].invoke
      }.to output(/Some feeds have issues/).to_stdout
    end

    context "when all feeds are healthy" do
      before do
        EventFeed.destroy_all
        create(:event_feed, :recently_fetched, event_count: 10)
      end

      it "shows success message" do
        expect {
          Rake::Task["events:health"].invoke
        }.to output(/✓ All feeds are healthy!/).to_stdout
      end
    end
  end

  describe "events:archive_old" do
    let!(:old_event) do
      create(:external_event, start_time: 10.days.ago)
    end

    let!(:recent_event) do
      create(:external_event, start_time: 5.days.ago)
    end

    let!(:upcoming_event) do
      create(:external_event, :upcoming)
    end

    it "archives events older than 7 days" do
      expect {
        Rake::Task["events:archive_old"].invoke
      }.to change { old_event.reload.archived_at }.from(nil)
    end

    it "does not archive recent past events" do
      Rake::Task["events:archive_old"].invoke

      expect(recent_event.reload.archived_at).to be_nil
    end

    it "does not archive upcoming events" do
      Rake::Task["events:archive_old"].invoke

      expect(upcoming_event.reload.archived_at).to be_nil
    end

    it "outputs count of archived events" do
      expect {
        Rake::Task["events:archive_old"].invoke
      }.to output(/Archived \d+ past events/).to_stdout
    end

    context "when no old events exist" do
      before do
        ExternalEvent.where("start_time < ?", 7.days.ago).destroy_all
      end

      it "shows no events to archive message" do
        expect {
          Rake::Task["events:archive_old"].invoke
        }.to output(/No past events to archive/).to_stdout
      end
    end
  end

  describe "events:cleanup" do
    let!(:very_old_archived) do
      create(:external_event,
        archived_at: 60.days.ago,
        start_time: 60.days.ago)
    end

    let!(:recent_archived) do
      create(:external_event,
        archived_at: 10.days.ago,
        start_time: 10.days.ago)
    end

    it "deletes archived events older than 30 days by default" do
      expect {
        Rake::Task["events:cleanup"].invoke
      }.to change(ExternalEvent, :count).by(-1)

      expect(ExternalEvent.find_by(id: very_old_archived.id)).to be_nil
      expect(ExternalEvent.find_by(id: recent_archived.id)).to be_present
    end

    it "accepts custom days parameter" do
      expect {
        Rake::Task["events:cleanup"].invoke(5)
      }.to change(ExternalEvent, :count).by(-2)

      expect(ExternalEvent.find_by(id: very_old_archived.id)).to be_nil
      expect(ExternalEvent.find_by(id: recent_archived.id)).to be_nil
    end

    it "outputs count of deleted events" do
      expect {
        Rake::Task["events:cleanup"].invoke
      }.to output(/Deleted \d+ old archived events/).to_stdout
    end

    context "when no old archived events exist" do
      before do
        ExternalEvent.where("archived_at < ?", 30.days.ago).destroy_all
      end

      it "shows no events to clean message" do
        expect {
          Rake::Task["events:cleanup"].invoke
        }.to output(/No old events to clean up/).to_stdout
      end
    end
  end

  describe "events:help" do
    it "displays available tasks" do
      output = capture_stdout do
        Rake::Task["events:help"].invoke
      end

      expect(output).to include("EVENTS RAKE TASKS")
      expect(output).to include("Available tasks:")
      expect(output).to include("rake events:fetch")
      expect(output).to include("rake events:summary")
      expect(output).to include("rake events:upcoming")
    end

    it "shows examples" do
      expect {
        Rake::Task["events:help"].invoke
      }.to output(/Examples:/).to_stdout
    end
  end

  describe "events (default task)" do
    it "invokes the help task" do
      # The "events" task depends on "events:help", so it should produce help output
      output = capture_stdout do
        Rake::Task["events"].invoke
      end

      expect(output).to include("EVENTS RAKE TASKS")
      expect(output).to include("Available tasks:")
    end
  end
end
