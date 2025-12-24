require "rails_helper"

RSpec.describe "Event Discovery", type: :system do
  before do
    driven_by(:rack_test)
  end

  describe "browsing events" do
    let!(:rock_concert) do
      create(:external_event,
        title: "Rock Concert at Bottom of the Hill",
        venue: "Bottom of the Hill",
        price: 25.00,
        start_time: 3.days.from_now,
        category_tags: %w[music rock])
    end

    let!(:free_event) do
      create(:external_event,
        title: "Free Community Festival",
        venue: "Golden Gate Park",
        price: nil,
        start_time: 5.days.from_now,
        category_tags: %w[festival community])
    end

    it "displays all events on the index page" do
      visit events_path

      expect(page).to have_content("Discover Events")
      expect(page).to have_content(rock_concert.title)
      expect(page).to have_content(free_event.title)
    end

    it "shows event details" do
      visit events_path

      expect(page).to have_content(rock_concert.venue)
      expect(page).to have_content("$25.0")
      expect(page).to have_content("Free")
    end

    it "displays category tags" do
      visit events_path

      expect(page).to have_content("music")
      expect(page).to have_content("rock")
    end
  end

  describe "filtering events" do
    let!(:weekend_event) do
      saturday = Date.current
      saturday += 1.day until saturday.saturday?
      create(:external_event,
        title: "Weekend Concert",
        start_time: saturday.to_time.change(hour: 20))
    end

    let!(:weekday_event) do
      monday = Date.current
      monday += 1.day until monday.monday?
      create(:external_event,
        title: "Weekday Show",
        start_time: monday.to_time.change(hour: 20))
    end

    let!(:free_event) do
      create(:external_event,
        title: "Free Event",
        price: 0)
    end

    let!(:paid_event) do
      create(:external_event,
        title: "Paid Event",
        price: 30.00)
    end

    it "filters by weekends only" do
      visit events_path

      check "Weekends Only"
      click_button "Apply"

      expect(page).to have_content(weekend_event.title)
      expect(page).not_to have_content(weekday_event.title)
    end

    it "filters by free events" do
      visit events_path

      check "Free Events"
      click_button "Apply"

      expect(page).to have_content(free_event.title)
      expect(page).not_to have_content(paid_event.title)
    end

    it "filters by max price" do
      visit events_path

      fill_in "Max Price", with: "20"
      click_button "Apply"

      expect(page).to have_content(free_event.title)
      expect(page).not_to have_content(paid_event.title)
    end

    it "searches by text" do
      visit events_path

      fill_in "Search", with: "Weekend"
      click_button "Apply"

      expect(page).to have_content(weekend_event.title)
      expect(page).not_to have_content(weekday_event.title)
    end

    it "filters by date range" do
      today = Date.current
      next_week = 7.days.from_now.to_date

      near_event = create(:external_event,
        title: "This Week Event",
        start_time: 3.days.from_now)
      far_event = create(:external_event,
        title: "Next Month Event",
        start_time: 30.days.from_now)

      visit events_path

      fill_in "Start Date", with: today.to_s
      fill_in "End Date", with: next_week.to_s
      click_button "Apply"

      expect(page).to have_content(near_event.title)
      expect(page).not_to have_content(far_event.title)
    end

    it "clears all filters" do
      visit events_path

      check "Weekends Only"
      click_button "Apply"

      expect(page).to have_content(weekend_event.title)
      expect(page).not_to have_content(weekday_event.title)

      click_link "Clear"

      expect(page).to have_content(weekend_event.title)
      expect(page).to have_content(weekday_event.title)
    end
  end

  describe "viewing event details" do
    let(:event) do
      create(:external_event,
        title: "Amazing Concert",
        description: "This is a fantastic live music event",
        venue: "The Fillmore",
        price: 35.00,
        organizer: "Live Nation",
        start_time: 5.days.from_now.change(hour: 20, min: 0),
        end_time: 5.days.from_now.change(hour: 23, min: 0),
        category_tags: %w[music live concert])
    end

    it "shows full event details" do
      visit events_path
      click_link "View Details"

      expect(page).to have_content(event.title)
      expect(page).to have_content(event.description)
      expect(page).to have_content(event.venue)
      expect(page).to have_content("$35.0")
      expect(page).to have_content(event.organizer)
    end

    it "displays event time and duration" do
      visit event_path(event)

      expect(page).to have_content(event.start_time.strftime("%I:%M %p"))
      expect(page).to have_content("3.0 hours")
    end

    it "shows category tags" do
      visit event_path(event)

      expect(page).to have_content("music")
      expect(page).to have_content("live")
      expect(page).to have_content("concert")
    end
  end

  describe "adding events to calendar", js: true do
    let(:user) { create(:user) }
    let(:event) { create(:external_event, :upcoming) }

    before do
      sign_in user
    end

    it "adds event to user's calendar" do
      visit events_path

      expect {
        click_button "Add to Calendar"
      }.to change { user.activities.count }.by(1)

      expect(page).to have_content("Event added to your calendar")
    end

    it "creates Activity with correct attributes" do
      visit events_path
      click_button "Add to Calendar"

      activity = user.activities.last
      expect(activity.name).to eq(event.title)
      expect(activity.schedule_type).to eq("strict")
      expect(activity.source_url).to eq(event.source_url)
    end

    it "prevents adding duplicate events" do
      create(:activity, user: user, source_url: event.source_url)

      visit events_path

      expect {
        click_button "Add to Calendar"
      }.not_to change { user.activities.count }

      expect(page).to have_content("already added this event")
    end

    it "adds event from detail page" do
      visit event_path(event)

      expect {
        click_button "Add to Calendar"
      }.to change { user.activities.count }.by(1)

      expect(page).to have_current_path(events_path)
      expect(page).to have_content("Event added to your calendar")
    end
  end

  describe "free weekends feature" do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    context "when user has free weekends" do
      it "displays free weekends section" do
        visit events_path

        expect(page).to have_content("Your Free Weekends")
      end

      it "shows clickable weekend dates" do
        visit events_path

        within(".bg-purple-50") do
          expect(page).to have_css("a", minimum: 1)
        end
      end

      it "filters events by clicked weekend" do
        # Create event on upcoming Saturday
        saturday = Date.current
        saturday += 1.day until saturday.saturday?
        weekend_event = create(:external_event,
          title: "Saturday Event",
          start_time: saturday.to_time)

        visit events_path

        # Click first free weekend
        within(".bg-purple-50") do
          first("a").click
        end

        # Should show events for that weekend
        expect(page).to have_current_path(/weekends_only=true/)
      end
    end

    context "when user has no free weekends" do
      before do
        # Schedule activities for all weekends
        12.times do |i|
          saturday = (Date.current + i.weeks).beginning_of_week(:sunday) + 6.days
          create(:activity,
            user: user,
            schedule_type: "strict",
            start_time: saturday.to_time,
            end_time: saturday.to_time + 2.hours)
        end
      end

      it "does not show free weekends section" do
        visit events_path

        expect(page).not_to have_content("Your Free Weekends")
      end
    end
  end

  describe "pagination" do
    before do
      create_list(:external_event, 30, :upcoming)
    end

    it "displays page navigation" do
      visit events_path

      expect(page).to have_content("Page 1 of")
      expect(page).to have_link("Next →")
    end

    it "navigates to next page" do
      visit events_path
      click_link "Next →"

      expect(page).to have_content("Page 2 of")
      expect(page).to have_link("← Previous")
    end

    it "navigates back to previous page" do
      visit events_path(page: 2)
      click_link "← Previous"

      expect(page).to have_content("Page 1 of")
    end

    it "maintains filters across pages" do
      create(:external_event, title: "Special Weekend Event", start_time: next_saturday)

      visit events_path
      check "Weekends Only"
      click_button "Apply"

      if page.has_link?("Next →")
        click_link "Next →"
        expect(page).to have_field("Weekends Only", checked: true)
      end
    end

    def next_saturday
      date = Date.current
      date += 1.day until date.saturday?
      date.to_time
    end
  end

  describe "navigation" do
    it "has link to events from main navigation" do
      visit root_path

      expect(page).to have_link("Discover Events")
    end

    it "navigates to events index" do
      visit root_path
      click_link "Discover Events"

      expect(page).to have_current_path(events_path)
      expect(page).to have_content("Discover Events")
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "shows link to My Activities" do
        visit events_path

        expect(page).to have_link("My Activities")
      end

      it "navigates to activities page" do
        visit events_path
        click_link "My Activities"

        expect(page).to have_current_path(activities_path)
      end
    end

    context "when not signed in" do
      it "does not show My Activities link" do
        visit events_path

        expect(page).not_to have_link("My Activities")
      end
    end
  end

  describe "empty state" do
    before do
      ExternalEvent.destroy_all
    end

    it "displays helpful message when no events exist" do
      visit events_path

      expect(page).to have_content("No events found")
      expect(page).to have_content("Try adjusting your filters or check back later!")
    end

    it "shows calendar icon in empty state" do
      visit events_path

      within(".text-center") do
        expect(page).to have_css("svg")
      end
    end
  end
end
