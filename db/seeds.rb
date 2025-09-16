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
