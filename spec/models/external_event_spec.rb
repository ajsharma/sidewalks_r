require "rails_helper"

RSpec.describe ExternalEvent, type: :model do
  describe "associations" do
    it "belongs to event_feed" do
      event = create(:external_event)
      expect(event.event_feed).to be_a(EventFeed)
    end
  end

  describe "validations" do
    it "validates presence of title" do
      event = build(:external_event, title: nil)
      expect(event).not_to be_valid
      expect(event.errors[:title]).to be_present
    end

    it "validates presence of start_time" do
      event = build(:external_event, start_time: nil)
      expect(event).not_to be_valid
      expect(event.errors[:start_time]).to be_present
    end

    it "validates presence of source_url" do
      event = build(:external_event, source_url: nil)
      expect(event).not_to be_valid
      expect(event.errors[:source_url]).to be_present
    end

    it "validates length of title" do
      event = build(:external_event, title: "A")
      expect(event).not_to be_valid

      event.title = "A" * 201
      expect(event).not_to be_valid

      event.title = "Valid Title"
      expect(event).to be_valid
    end

    describe "end_time_after_start_time" do
      it "is valid when end_time is after start_time" do
        event = build(:external_event, start_time: 1.hour.from_now, end_time: 2.hours.from_now)
        expect(event).to be_valid
      end

      it "is invalid when end_time is before start_time" do
        event = build(:external_event, start_time: 2.hours.from_now, end_time: 1.hour.from_now)
        expect(event).not_to be_valid
        expect(event.errors[:end_time]).to include("must be after start time")
      end

      it "is invalid when end_time equals start_time" do
        time = 1.hour.from_now
        event = build(:external_event, start_time: time, end_time: time)
        expect(event).not_to be_valid
        expect(event.errors[:end_time]).to include("must be after start time")
      end

      it "is invalid when duration exceeds 24 hours" do
        event = build(:external_event, start_time: 1.hour.from_now, end_time: 26.hours.from_now)
        expect(event).not_to be_valid
        expect(event.errors[:end_time]).to include("event duration cannot exceed 24 hours")
      end
    end
  end

  describe ".model_name" do
    it "returns Event as the model name for routing" do
      expect(ExternalEvent.model_name.name).to eq("Event")
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only non-archived events" do
        active_event = create(:external_event)
        archived_event = create(:external_event, :archived)

        expect(ExternalEvent.active).to include(active_event)
        expect(ExternalEvent.active).not_to include(archived_event)
      end
    end

    describe ".upcoming" do
      it "returns events starting today or later" do
        upcoming_event = create(:external_event, :upcoming)
        past_event = create(:external_event, :past)

        expect(ExternalEvent.upcoming).to include(upcoming_event)
        expect(ExternalEvent.upcoming).not_to include(past_event)
      end

      it "includes events starting today" do
        today_event = create(:external_event,
          start_time: Time.current.end_of_day - 3.hours,
          end_time: Time.current.end_of_day)
        expect(ExternalEvent.upcoming).to include(today_event)
      end
    end

    describe ".by_date_range" do
      it "returns events within specified date range" do
        start_date = Date.current
        end_date = 7.days.from_now.to_date
        in_range = create(:external_event,
          start_time: 3.days.from_now,
          end_time: 3.days.from_now + 2.hours)
        before_range = create(:external_event,
          start_time: 1.day.ago,
          end_time: 1.day.ago + 2.hours)
        after_range = create(:external_event,
          start_time: 10.days.from_now,
          end_time: 10.days.from_now + 2.hours)

        results = ExternalEvent.by_date_range(start_date, end_date)
        expect(results).to include(in_range)
        expect(results).not_to include(before_range)
        expect(results).not_to include(after_range)
      end
    end

    describe ".free_only" do
      it "returns events with nil price" do
        free_event = create(:external_event, price: nil)
        expect(ExternalEvent.free_only).to include(free_event)
      end

      it "returns events with zero price" do
        free_event = create(:external_event, price: 0)
        expect(ExternalEvent.free_only).to include(free_event)
      end

      it "excludes paid events" do
        paid_event = create(:external_event, :paid)
        expect(ExternalEvent.free_only).not_to include(paid_event)
      end
    end

    describe ".weekends_only" do
      it "returns Saturday events" do
        saturday_event = create(:external_event, :weekend)
        expect(ExternalEvent.weekends_only).to include(saturday_event)
      end

      it "excludes weekday events" do
        # Create event on a Monday
        monday = Date.current
        monday += 1.day until monday.monday?
        weekday_event = create(:external_event,
          start_time: monday.to_time,
          end_time: monday.to_time + 2.hours)

        expect(ExternalEvent.weekends_only).not_to include(weekday_event)
      end
    end

    describe ".search_by_text" do
      it "finds events by title" do
        event = create(:external_event, title: "Unique Band Name")
        results = ExternalEvent.search_by_text("Unique")
        expect(results).to include(event)
      end

      it "finds events by description" do
        event = create(:external_event, description: "Special concert description")
        results = ExternalEvent.search_by_text("Special")
        expect(results).to include(event)
      end

      it "finds events by venue" do
        event = create(:external_event, venue: "The Fillmore")
        results = ExternalEvent.search_by_text("Fillmore")
        expect(results).to include(event)
      end

      it "is case insensitive" do
        event = create(:external_event, title: "Rock Concert")
        results = ExternalEvent.search_by_text("ROCK")
        expect(results).to include(event)
      end

      it "sanitizes SQL LIKE wildcards" do
        event = create(:external_event, title: "Band Name")
        # Should not treat % as wildcard
        results = ExternalEvent.search_by_text("%")
        expect(results).not_to include(event)
      end
    end
  end

  describe "#archived?" do
    it "returns true when archived_at is present" do
      event = create(:external_event, :archived)
      expect(event.archived?).to be true
    end

    it "returns false when archived_at is nil" do
      event = create(:external_event)
      expect(event.archived?).to be false
    end
  end

  describe "#archive!" do
    it "sets archived_at timestamp" do
      event = create(:external_event)
      event.archive!

      expect(event.archived_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "#free?" do
    it "returns true when price is nil" do
      event = create(:external_event, price: nil)
      expect(event.free?).to be true
    end

    it "returns true when price is zero" do
      event = create(:external_event, price: 0)
      expect(event.free?).to be true
    end

    it "returns false when price is positive" do
      event = create(:external_event, :paid)
      expect(event.free?).to be false
    end
  end

  describe "#weekend?" do
    it "returns true for Saturday events" do
      saturday = Date.current
      saturday += 1.day until saturday.saturday?
      event = create(:external_event,
        start_time: saturday.to_time,
        end_time: saturday.to_time + 2.hours)
      expect(event.weekend?).to be true
    end

    it "returns true for Sunday events" do
      sunday = Date.current
      sunday += 1.day until sunday.sunday?
      event = create(:external_event,
        start_time: sunday.to_time,
        end_time: sunday.to_time + 2.hours)
      expect(event.weekend?).to be true
    end

    it "returns false for weekday events" do
      monday = Date.current
      monday += 1.day until monday.monday?
      event = create(:external_event,
        start_time: monday.to_time,
        end_time: monday.to_time + 2.hours)
      expect(event.weekend?).to be false
    end
  end

  describe "#duration_hours" do
    it "calculates duration in hours" do
      event = create(:external_event,
        start_time: 1.hour.from_now,
        end_time: 4.hours.from_now)
      expect(event.duration_hours).to eq(3.0)
    end

    it "returns nil when end_time is not set" do
      event = create(:external_event, end_time: nil)
      expect(event.duration_hours).to be_nil
    end

    it "rounds to one decimal place" do
      event = create(:external_event,
        start_time: 1.hour.from_now,
        end_time: 2.5.hours.from_now)
      expect(event.duration_hours).to eq(1.5)
    end
  end

  describe "#to_activity_params" do
    let(:user) { create(:user) }
    let(:event) do
      create(:external_event,
        title: "Test Event",
        description: "Test Description",
        start_time: 1.day.from_now,
        end_time: 1.day.from_now + 3.hours,
        source_url: "https://example.com/event",
        price: 25.00,
        organizer: "Test Organizer",
        category_tags: %w[music rock])
    end

    it "converts to Activity creation parameters" do
      params = event.to_activity_params(user)

      expect(params[:user]).to eq(user)
      expect(params[:name]).to eq("Test Event")
      expect(params[:description]).to eq("Test Description")
      expect(params[:schedule_type]).to eq("strict")
      expect(params[:start_time]).to eq(event.start_time)
      expect(params[:end_time]).to eq(event.end_time)
      expect(params[:source_url]).to eq("https://example.com/event")
      expect(params[:price]).to eq(25.00)
      expect(params[:organizer]).to eq("Test Organizer")
      expect(params[:category_tags]).to eq(%w[music rock])
      expect(params[:ai_generated]).to be false
    end

    it "calculates duration_minutes from duration_hours" do
      event = create(:external_event,
        start_time: 1.hour.from_now,
        end_time: 3.hours.from_now)
      params = event.to_activity_params(user)

      expect(params[:duration_minutes]).to eq(120)
    end

    it "sets duration_minutes to nil when end_time is not set" do
      event = create(:external_event, end_time: nil)
      params = event.to_activity_params(user)

      expect(params[:duration_minutes]).to be_nil
    end
  end
end
