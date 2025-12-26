FactoryBot.define do
  factory :playlist_activity do
    playlist
    activity
    sequence(:position) { |n| n }
    archived_at { nil }
  end
end
