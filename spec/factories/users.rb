FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password" }
    name { "John Doe" }
    sequence(:slug) { |n| "john-doe-#{n}" }
    timezone { "Pacific Time (US & Canada)" }
    archived_at { nil }
  end
end
