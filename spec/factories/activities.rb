FactoryBot.define do
  factory :activity do
    association :user
    sequence(:name) { |n| "Activity #{n}" }
    sequence(:slug) { |n| "activity-#{n}" }
    description { "Activity description" }
    links { nil }
    schedule_type { "flexible" }
    start_time { nil }
    end_time { nil }
    deadline { nil }
    max_frequency_days { 7 }
    archived_at { nil }
    ai_generated { false }
    source_url { nil }
    image_url { nil }
    price { nil }
    organizer { nil }
    suggested_months { [] }
    suggested_days_of_week { [] }
    suggested_time_of_day { nil }
    category_tags { [] }

    trait :strict do
      schedule_type { "strict" }
      start_time { 1.day.from_now.change(hour: 9, min: 0) }
      end_time { 1.day.from_now.change(hour: 10, min: 0) }
    end

    trait :deadline_based do
      schedule_type { "deadline" }
      deadline { 1.week.from_now }
    end

    trait :ai_generated do
      ai_generated { true }
      suggested_months { [5, 6, 7, 8, 9] }
      suggested_days_of_week { [0, 6] }
      suggested_time_of_day { "morning" }
      category_tags { ["outdoor", "food", "social"] }
    end
  end
end
