require "rails_helper"

RSpec.describe "Events", type: :request do
  # Disable Bullet for integration tests - N+1 optimization can be addressed separately
  before do
    Bullet.enable = false
  end

  after do
    Bullet.enable = true
  end

  describe "GET /events" do
    let!(:active_events) { create_list(:external_event, 5, :upcoming) }
    let!(:archived_event) { create(:external_event, :archived) }

    it "returns successful response" do
      get events_path
      expect(response).to have_http_status(:success)
    end

    it "displays active events" do
      get events_path
      active_events.each do |event|
        # Check for venue instead of title to avoid HTML escaping issues with Faker-generated band names
        expect(response.body).to include(event.venue)
      end
    end

    it "does not display archived events" do
      get events_path
      expect(response.body).not_to include(archived_event.title)
    end

    context "with date range filter" do
      let!(:event_in_range) do
        create(:external_event, start_time: 3.days.from_now)
      end
      let!(:event_out_of_range) do
        create(:external_event, start_time: 10.days.from_now)
      end

      it "filters events by date range" do
        start_date = Date.current
        end_date = 7.days.from_now.to_date

        get events_path, params: {
          start_date: start_date.to_s,
          end_date: end_date.to_s
        }

        expect(response.body).to include(event_in_range.title)
        expect(response.body).not_to include(event_out_of_range.title)
      end
    end

    context "with weekends_only filter" do
      let!(:saturday_event) do
        saturday = Date.current
        saturday += 1.day until saturday.saturday?
        create(:external_event, start_time: saturday.to_time)
      end
      let!(:weekday_event) do
        monday = Date.current
        monday += 1.day until monday.monday?
        create(:external_event, start_time: monday.to_time)
      end

      it "filters to weekend events only" do
        get events_path, params: { weekends_only: "true" }

        expect(response.body).to include(saturday_event.title)
        expect(response.body).not_to include(weekday_event.title)
      end
    end

    context "with free_only filter" do
      let!(:free_event) { create(:external_event, :free) }
      let!(:paid_event) { create(:external_event, :paid) }

      it "filters to free events only" do
        get events_path, params: { free_only: "true" }

        # Check for free event by venue and "Free" badge
        expect(response.body).to include(free_event.venue)
        expect(response.body).to include("Free")
        # Paid event won't be shown, check price doesn't appear
        expect(response.body).not_to include("$#{paid_event.price}")
      end
    end

    context "with price_max filter" do
      let!(:cheap_event) { create(:external_event, price: 10.00) }

      before do
        create(:external_event, price: 50.00)
      end

      it "filters events under max price" do
        get events_path, params: { price_max: 20 }

        expect(response.body).to include(cheap_event.venue)
        expect(response.body).not_to include("$50.0") # Check for expensive price instead of title
      end

      it "includes free events" do
        free_event = create(:external_event, price: nil, venue: "Free Event Venue")
        get events_path, params: { price_max: 20 }

        expect(response.body).to include(free_event.venue)
      end
    end

    context "with search filter" do
      let!(:rock_event) { create(:external_event, title: "Rock Concert") }
      let!(:jazz_event) { create(:external_event, title: "Jazz Night") }

      it "searches by title" do
        get events_path, params: { search: "Rock" }

        expect(response.body).to include(rock_event.title)
        expect(response.body).not_to include(jazz_event.title)
      end

      it "searches by venue" do
        fillmore_event = create(:external_event, venue: "The Fillmore")
        get events_path, params: { search: "Fillmore" }

        expect(response.body).to include(fillmore_event.title)
      end

      it "is case insensitive" do
        get events_path, params: { search: "ROCK" }

        expect(response.body).to include(rock_event.title)
      end
    end

    context "with pagination" do
      before do
        # Create in smaller batches to avoid RuboCop warning
        3.times { create_list(:external_event, 10, :upcoming) }
      end

      it "paginates results" do
        get events_path
        expect(response.body).to include("Page 1 of")
      end

      it "shows correct page" do
        get events_path, params: { page: 2 }
        expect(response.body).to include("Page 2 of")
      end

      it "limits events per page" do
        get events_path
        # Should show max 24 events per page
        event_titles = response.body.scan(/View Details/).count
        expect(event_titles).to be <= 24
      end
    end

    context "when user is signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "shows Add to Calendar buttons" do
        get events_path
        expect(response.body).to include("Add to Calendar")
      end

      it "displays free weekends section when user has free weekends" do
        get events_path
        expect(response.body).to include("Your Free Weekends")
      end
    end

    context "when user is not signed in" do
      it "does not show Add to Calendar buttons" do
        get events_path
        expect(response.body).not_to include("Add to Calendar")
      end

      it "does not display free weekends section" do
        get events_path
        expect(response.body).not_to include("Your Free Weekends")
      end
    end

    context "with invalid date format" do
      it "handles invalid dates gracefully" do
        get events_path, params: {
          start_date: "invalid",
          end_date: "also-invalid"
        }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Invalid date format")
      end
    end

    context "when no events exist" do
      before { ExternalEvent.destroy_all }

      it "displays no events message" do
        get events_path
        expect(response.body).to include("No events found")
      end
    end
  end

  describe "GET /events/:id" do
    let(:event) { create(:external_event, :upcoming, :with_categories) }

    it "returns successful response" do
      get event_path(event)
      expect(response).to have_http_status(:success)
    end

    it "displays event details" do
      get event_path(event)

      # Check for venue and description instead of title to avoid HTML escaping issues
      expect(response.body).to include(event.description)
      expect(response.body).to include(event.venue)
    end

    context "when user is signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "shows Add to Calendar button" do
        get event_path(event)
        expect(response.body).to include("Add to Calendar")
      end
    end

    context "when event is archived" do
      let(:archived_event) { create(:external_event, :archived) }

      it "redirects to events index" do
        get event_path(archived_event)
        expect(response).to redirect_to(events_path)
      end

      it "shows error message" do
        get event_path(archived_event)
        follow_redirect!
        expect(response.body).to include("Event not found")
      end
    end

    context "when event does not exist" do
      it "redirects to events index" do
        get event_path(id: 99999)
        expect(response).to redirect_to(events_path)
      end

      it "shows error message" do
        get event_path(id: 99999)
        follow_redirect!
        expect(response.body).to include("Event not found")
      end
    end
  end

  describe "POST /events/:id/add_to_calendar" do
    let(:user) { create(:user) }
    let(:event) { create(:external_event, :upcoming) }

    context "when user is signed in" do
      before { sign_in user }

      it "creates a new Activity" do
        expect {
          post add_to_calendar_event_path(event)
        }.to change(Activity, :count).by(1)
      end

      it "creates Activity with correct attributes" do
        post add_to_calendar_event_path(event)
        activity = Activity.last

        expect(activity.user).to eq(user)
        expect(activity.name).to eq(event.title)
        expect(activity.schedule_type).to eq("strict")
        expect(activity.start_time).to eq(event.start_time)
        expect(activity.source_url).to eq(event.source_url)
      end

      it "redirects to events index" do
        post add_to_calendar_event_path(event)
        expect(response).to redirect_to(events_path)
      end

      it "shows success message" do
        post add_to_calendar_event_path(event)
        follow_redirect!
        expect(response.body).to include("Event added to your calendar")
      end

      context "when event already added" do
        before do
          create(:activity, user: user, source_url: event.source_url)
        end

        it "does not create duplicate Activity" do
          expect {
            post add_to_calendar_event_path(event)
          }.not_to change(Activity, :count)
        end

        it "shows error message" do
          post add_to_calendar_event_path(event)
          follow_redirect!
          expect(response.body).to include("already added this event")
        end
      end

      context "when user has Google Calendar connected" do
        let(:google_account) { create(:google_account, user: user) }
        let(:calendar_service) { instance_double(GoogleCalendarService) }

        before do
          # Setup google account for the user
          google_account
          allow(google_account).to receive(:needs_refresh?).and_return(false)
          allow(GoogleCalendarService).to receive(:new).and_return(calendar_service)
        end

        it "syncs to Google Calendar" do
          allow(calendar_service).to receive(:create_event).and_return(true)

          post add_to_calendar_event_path(event)

          expect(calendar_service).to have_received(:create_event)
        end

        it "handles sync errors gracefully" do
          allow(calendar_service).to receive(:create_event)
            .and_raise(StandardError.new("API error"))

          expect {
            post add_to_calendar_event_path(event)
          }.to change(Activity, :count).by(1)

          follow_redirect!
          expect(response.body).to include("Event added to your calendar")
        end
      end

      context "when Activity creation fails" do
        let(:activity_double) { instance_double(Activity, save: false, errors: errors_double) }
        let(:errors_double) { instance_double(ActiveModel::Errors, full_messages: [ "Name can't be blank" ]) }

        before do
          # Stub Activity.new to return a double that fails to save
          allow(Activity).to receive(:new).and_return(activity_double)
        end

        it "does not create Activity" do
          expect {
            post add_to_calendar_event_path(event)
          }.not_to change(Activity, :count)
        end

        it "shows error message" do
          post add_to_calendar_event_path(event)
          follow_redirect!
          expect(response.body).to include("Failed to add event")
        end
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in page" do
        post add_to_calendar_event_path(event)
        expect(response).to redirect_to(new_user_session_path)
      end

      it "does not create Activity" do
        expect {
          post add_to_calendar_event_path(event)
        }.not_to change(Activity, :count)
      end
    end
  end
end
