source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", ">= 8.0.2.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Authentication and OAuth
gem "devise"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"

# Google Calendar API
gem "google-apis-calendar_v3"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Catch unsafe migrations in development [https://github.com/ankane/strong_migrations]
gem "strong_migrations"

# Configuration management with multiple sources [https://github.com/palkan/anyway_config]
gem "anyway_config", "~> 2.0"

# AI service integrations
gem "ruby-openai", "~> 8.3"  # OpenAI/ChatGPT API client

# RSS/Atom feed parsing
gem "feedjira"  # RSS/Atom parsing with custom namespace support

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Load environment variables from .env files [https://github.com/bkeepers/dotenv]
  gem "dotenv-rails"

  # RSpec testing framework [https://rspec.info/]
  gem "rspec-rails", "~> 7.1"

  # Test data generation [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails"

  # Fake data generation [https://github.com/faker-ruby/faker]
  gem "faker"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Security vulnerability scanner for Ruby gems [https://github.com/postmodern/bundler-audit]
  gem "bundler-audit", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RuboCop extension for RSpec [https://github.com/rubocop/rubocop-rspec]
  gem "rubocop-rspec", require: false

  # RuboCop extension for FactoryBot [https://github.com/rubocop/rubocop-factory_bot]
  gem "rubocop-factory_bot", require: false

  # Code smell detection for Ruby [https://github.com/troessner/reek]
  gem "reek", require: false

  # Rails best practices code analyzer [https://github.com/railsbp/rails_best_practices]
  gem "rails_best_practices", require: false

  # Performance monitoring and benchmarking [https://github.com/schneems/derailed_benchmarks]
  gem "derailed_benchmarks", require: false

  # N+1 query detection [https://github.com/flyerhzm/bullet]
  gem "bullet"

  # YARD documentation generation [https://yardoc.org/]
  gem "yard", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Annotate models with schema information [https://github.com/drwl/annotaterb]
  gem "annotaterb"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Code coverage analysis [https://github.com/simplecov-ruby/simplecov]
  gem "simplecov", require: false

  # Accessibility testing with axe-core [https://github.com/dequelabs/axe-core-gems]
  gem "axe-core-capybara"

  # Additional RSpec matchers [https://github.com/thoughtbot/shoulda-matchers]
  gem "shoulda-matchers", "~> 6.0"

  # HTTP request mocking [https://github.com/vcr/vcr]
  gem "vcr", "~> 6.4"
  gem "webmock", "~> 3.25"
end
