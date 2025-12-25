FactoryBot.define do
  factory :external_event do
    event_feed
    title { Faker::Music.band }
    description { Faker::Lorem.paragraph }
    start_time { 2.days.from_now.change(hour: 20, min: 0) }
    end_time { (start_time || 2.days.from_now.change(hour: 20, min: 0)) + 3.hours }
    location { "San Francisco, CA" }
    venue { "Bottom of the Hill" }
    source_url { Faker::Internet.url }
    price { nil }
    price_details { nil }
    organizer { nil }
    category_tags { [] }
    external_id { SecureRandom.uuid }
    archived_at { nil }
    last_synced_at { Time.current }

    trait :free do
      price { 0 }
    end

    trait :paid do
      price { 25.00 }
      price_details { "Tickets available at door" }
    end

    trait :archived do
      archived_at { 1.week.ago }
    end

    trait :past do
      start_time { 3.days.ago.change(hour: 20, min: 0) }
      end_time { 3.days.ago.change(hour: 23, min: 0) }
    end

    trait :upcoming do
      start_time { 3.days.from_now.change(hour: 20, min: 0) }
      end_time { 3.days.from_now.change(hour: 23, min: 0) }
    end

    trait :weekend do
      start_time { next_saturday.change(hour: 20, min: 0) }
      end_time { next_saturday.change(hour: 23, min: 0) }
    end

    trait :with_categories do
      category_tags { %w[music rock live-music] }
    end

    trait :with_organizer do
      organizer { Faker::Company.name }
    end

    # Helper method to find next Saturday
    transient do
      next_saturday do
        date = Date.current
        date += 1.day until date.saturday?
        date.to_time
      end
    end
  end
end
