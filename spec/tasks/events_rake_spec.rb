require "rails_helper"
require "rake"

RSpec.describe "events rake tasks" do
  before(:all) do
    Rake.application.rake_require "tasks/events"
    Rake::Task.define_task(:environment)
  end

  before(:each) do
    Rake::Task.tasks.each(&:reenable)
  end

  describe "events:fetch" do
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

      expect {
        Rake::Task["events:fetch"].invoke
      }.to output(/Fetching RSS event feeds/).to_stdout
        .and output(/Fetch Complete!/).to_stdout
        .and output(/Events added:/).to_stdout
    end
  end

  describe "events:summary" do
    let!(:feed) { create(:event_feed, :recently_fetched) }
    let!(:active_events) { create_list(:external_event, 5, :upcoming, event_feed: feed) }
    let!(:archived_events) { create_list(:external_event, 2, :archived, event_feed: feed) }

    it "displays overall statistics" do
      expect {
        Rake::Task["events:summary"].invoke
      }.to output(/OVERALL STATISTICS/).to_stdout
        .and output(/Total events:/).to_stdout
        .and output(/Active events:/).to_stdout
        .and output(/Upcoming events:/).to_stdout
    end

    it "displays feed breakdown" do
      expect {
        Rake::Task["events:summary"].invoke
      }.to output(/FEED BREAKDOWN/).to_stdout
        .and output(/#{feed.name}/).to_stdout
        .and output(/Events: \d+/).to_stdout
    end

    it "shows price breakdown" do
      create(:external_event, :free, :upcoming)
      create(:external_event, :paid, :upcoming)

      expect {
        Rake::Task["events:summary"].invoke
      }.to output(/PRICE BREAKDOWN/).to_stdout
        .and output(/Free events:/).to_stdout
        .and output(/Paid events:/).to_stdout
    end

    it "shows weekend events count" do
      saturday = Date.current
      saturday += 1.day until saturday.saturday?
      create(:external_event, start_time: saturday.to_time)

      expect {
        Rake::Task["events:summary"].invoke
      }.to output(/Weekend events:/).to_stdout
    end

    it "shows top categories" do
      create(:external_event, :upcoming, category_tags: %w[music rock])
      create(:external_event, :upcoming, category_tags: %w[music jazz])

      expect {
        Rake::Task["events:summary"].invoke
      }.to output(/TOP CATEGORIES/).to_stdout
        .and output(/music:/).to_stdout
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
      expect {
        Rake::Task["events:upcoming"].invoke
      }.to output(/UPCOMING EVENTS \(Next 7 days\)/).to_stdout
        .and output(/#{near_event.title}/).to_stdout
    end

    it "does not show events beyond default range" do
      expect {
        Rake::Task["events:upcoming"].invoke
      }.to output(/#{near_event.title}/).to_stdout
        .and not_to output(/#{far_event.title}/).to_stdout
    end

    it "accepts custom days parameter" do
      expect {
        Rake::Task["events:upcoming"].invoke(60)
      }.to output(/UPCOMING EVENTS \(Next 60 days\)/).to_stdout
        .and output(/#{far_event.title}/).to_stdout
    end

    it "groups events by date" do
      create(:external_event,
        title: "Event 1",
        start_time: 2.days.from_now.change(hour: 14))
      create(:external_event,
        title: "Event 2",
        start_time: 2.days.from_now.change(hour: 20))

      expect {
        Rake::Task["events:upcoming"].invoke
      }.to output(/2 events/).to_stdout
    end

    it "shows price and venue information" do
      create(:external_event,
        :free,
        :upcoming,
        venue: "The Fillmore",
        start_time: 2.days.from_now)

      expect {
        Rake::Task["events:upcoming"].invoke
      }.to output(/\[FREE\]/).to_stdout
        .and output(/@ The Fillmore/).to_stdout
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
      expect {
        Rake::Task["events:health"].invoke
      }.to output(/✓.*Active/).to_stdout
        .and output(/✓.*No errors/).to_stdout
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
      expect {
        Rake::Task["events:help"].invoke
      }.to output(/EVENTS RAKE TASKS/).to_stdout
        .and output(/Available tasks:/).to_stdout
        .and output(/rake events:fetch/).to_stdout
        .and output(/rake events:summary/).to_stdout
        .and output(/rake events:upcoming/).to_stdout
    end

    it "shows examples" do
      expect {
        Rake::Task["events:help"].invoke
      }.to output(/Examples:/).to_stdout
    end
  end

  describe "events (default task)" do
    it "invokes the help task" do
      expect(Rake::Task["events:help"]).to receive(:invoke)
      Rake::Task["events"].invoke
    end
  end
end
