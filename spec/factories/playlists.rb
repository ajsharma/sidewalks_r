FactoryBot.define do
  factory :playlist do
    user
    sequence(:name) { |n| "Playlist #{n}" }
    sequence(:slug) { |n| "playlist-#{n}" }
    description { "Playlist description" }
    archived_at { nil }
  end
end
