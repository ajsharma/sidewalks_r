FactoryBot.define do
  factory :google_account do
    user
    sequence(:email) { |n| "google#{n}@gmail.com" }
    sequence(:google_id) { |n| "google#{n}23" }
    access_token { "test_access_token" }
    refresh_token { "test_refresh_token" }
    expires_at { 1.hour.from_now }
    calendar_list { '[{"id": "primary", "summary": "Primary Calendar"}]' }
    archived_at { nil }
  end
end
