# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Development user for testing
if Rails.env.development?
  user = User.find_or_create_by!(email: "user@sidewalkshq.com") do |u|
    u.name = "Sidewalks User"
    u.password = "sidewalks"
    u.password_confirmation = "sidewalks"
  end

  puts "Development user created: #{user.email} (password: sidewalks)"
end

# Event feeds for discovering SF events
EventFeed.find_or_create_by!(url: "https://www.bottomofthehill.com/RSS.xml") do |feed|
  feed.name = "Bottom of the Hill"
  feed.feed_type = "rss"
  feed.active = true
end

EventFeed.find_or_create_by!(url: "https://sf.funcheap.com/feed") do |feed|
  feed.name = "FunCheap SF"
  feed.feed_type = "rss"
  feed.active = true
end

EventFeed.find_or_create_by!(url: "https://www.eddies-list.com/feed") do |feed|
  feed.name = "Eddie's List"
  feed.feed_type = "rss"
  feed.active = true
end

puts "Event feeds created: #{EventFeed.count} feeds"
