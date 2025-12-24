FactoryBot.define do
  factory :event_feed do
    name { "Bottom of the Hill" }
    url { "https://www.bottomofthehill.com/RSS.xml" }
    feed_type { "rss" }
    active { true }
    last_fetched_at { nil }
    last_error { nil }
    event_count { 0 }

    trait :funcheap do
      name { "FunCheap SF" }
      url { "https://sf.funcheap.com/rss-date/" }
    end

    trait :eddies_list do
      name { "Eddie's List" }
      url { "https://www.eddies-list.com/feed" }
    end

    trait :inactive do
      active { false }
    end

    trait :with_error do
      last_error { "Connection timeout" }
    end

    trait :recently_fetched do
      last_fetched_at { 1.hour.ago }
      event_count { 10 }
    end

    trait :stale do
      last_fetched_at { 12.hours.ago }
    end
  end
end
