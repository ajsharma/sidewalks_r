FactoryBot.define do
  factory :playlist do
    association :user
    sequence(:name) { |n| "Playlist #{n}" }
    sequence(:slug) { |n| "playlist-#{n}" }
    description { "Playlist description" }
    archived_at { nil }
  end
end
