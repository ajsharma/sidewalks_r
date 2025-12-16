FactoryBot.define do
  factory :playlist_activity do
    association :playlist
    association :activity
    sequence(:position) { |n| n }
    archived_at { nil }
  end
end
