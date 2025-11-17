# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 8 application called "Sidewalks" that uses modern Rails conventions with PostgreSQL, Tailwind CSS, and is deployed on Render.com.

## Development Commands

### Setup and Installation
```bash
bin/setup                   # Initial setup script
bundle install              # Install Ruby dependencies
bin/rails db:create         # Create databases
bin/rails db:migrate        # Run database migrations
bin/rails db:seed           # Seed the database
```

### Development Server
```bash
bin/dev                     # Start development server with Procfile.dev (Rails + Tailwind CSS watcher)
bin/rails server            # Start Rails server only
bin/rails tailwindcss:watch # Watch and compile Tailwind CSS
```

### Quick Development Workflow
```bash
bin/go                      # Run full development pipeline: setup, tests, security, code quality, linting
```

### CI/CD Pipeline
The project includes a comprehensive CI/CD pipeline with:
- **Parallel job execution** - Security scanning, linting, and testing run in parallel
- **Security scanning** - Brakeman for Rails vulnerabilities, bundle-audit for gem vulnerabilities, importmap audit for JS dependencies
- **Code quality analysis** - RuboCop styling, Reek code smells, Rails best practices
- **Automated testing** - Full test suite with SimpleCov coverage reporting
- **Performance monitoring** - Bullet detects N+1 queries in development/test
- **Migration safety** - Strong migrations prevents unsafe database changes

### Database Operations
```bash
bin/rails db:migrate        # Run pending migrations
bin/rails db:rollback       # Rollback last migration
bin/rails db:reset          # Drop, create, migrate, and seed database
bin/rails db:schema:load    # Load schema into database
```

### Testing
```bash
bin/rails test             # Run all tests
bin/rails test test/models/specific_test.rb  # Run specific test file
```

### Code Quality and Linting
```bash
bin/rubocop                # Run RuboCop linter
bin/rubocop -a             # Run RuboCop with auto-corrections
bin/brakeman               # Run security analysis
bundle exec bundle-audit --update  # Audit Ruby gems for security vulnerabilities
bundle exec reek .         # Check for code smells
bundle exec rails_best_practices .  # Rails-specific code analysis
```

### Asset Management
```bash
bin/rails assets:precompile # Compile assets for production
bin/rails assets:clean      # Clean old compiled assets
```

### Console and Utilities
```bash
bin/rails console          # Start Rails console
bin/rails generate         # Use Rails generators
bin/rails routes           # Show all routes
```

## Architecture and Tech Stack

### Core Framework
- **Rails 8.0.2** - Latest Rails with modern conventions
- **PostgreSQL** - Primary database
- **Puma** - Web server

### Frontend Stack
- **Tailwind CSS** - Utility-first CSS framework via tailwindcss-rails gem
- **Turbo Rails** - SPA-like page acceleration
- **Stimulus Rails** - Modest JavaScript framework
- **Importmap Rails** - ES6 modules without bundling
- **Propshaft** - Modern asset pipeline

### Background Processing and Caching
- **Solid Queue** - Database-backed job queue for Active Job
- **Solid Cache** - Database-backed caching for Rails.cache
- **Solid Cable** - Database-backed Action Cable adapter

### Development and Testing
- **Rubocop Rails Omakase** - Ruby styling and linting
- **Brakeman** - Security vulnerability scanner
- **Bundler Audit** - Ruby gem security vulnerability scanner
- **Reek** - Code smell detection
- **Rails Best Practices** - Rails-specific code analyzer
- **Strong Migrations** - Catch unsafe migrations in development
- **Bullet** - N+1 query detection
- **SimpleCov** - Code coverage analysis
- **Axe Core Capybara** - Accessibility testing
- **Capybara + Selenium** - System testing
- **Debug gem** - Debugging tools

### Deployment
- **Render.com** - Primary deployment platform
- **Kamal** - Docker deployment tool (available but not primary)
- **Thruster** - HTTP asset caching and compression

## Project Structure

```
app/
├── controllers/           # Application controllers
├── models/               # ActiveRecord models
├── views/                # ERB templates
├── helpers/              # View helpers
├── jobs/                 # Background jobs
├── mailers/              # Action Mailer classes
├── assets/               # Images, stylesheets
└── javascript/           # Stimulus controllers and JS

config/                   # Application configuration
├── environments/         # Environment-specific configs
├── initializers/         # Rails initializers
├── routes.rb            # Application routes
└── database.yml         # Database configuration

db/
├── migrate/             # Database migrations
└── schema.rb           # Current database schema

test/                    # Test suite
├── controllers/         # Controller tests
├── models/             # Model tests
├── system/             # System/integration tests
└── fixtures/           # Test data
```

## Development Workflow

### Adding New Features
1. Generate models/controllers with `bin/rails generate`
2. Write migrations and run `bin/rails db:migrate`
3. Add routes in `config/routes.rb`
4. Use Stimulus for JavaScript interactions
5. Style with Tailwind CSS classes
6. Write tests in appropriate test/ subdirectories

### Database Changes
- Always use migrations for schema changes
- Run `bin/rails db:migrate` after creating migrations
- Update `db/seeds.rb` for sample data

### Styling
- Use Tailwind CSS utility classes directly in ERB templates
- Custom styles should be added to `app/assets/stylesheets/application.tailwind.css`
- The CSS watcher runs automatically with `bin/dev`

### JavaScript
- Use Stimulus controllers for interactive behavior
- Place controllers in `app/javascript/controllers/`
- Import maps handle module loading (see `config/importmap.rb`)

## Deployment

### Render.com (Primary)
- Build command: `./bin/render/build.sh`
- Start command: `./bin/rails server`
- Environment variables configured in render.yaml
- Database: PostgreSQL (sidewalks_production)

### Build Process
The `bin/render/build.sh` script handles:
1. `bundle install`
2. `bin/rails assets:precompile`
3. `bin/rails assets:clean`
4. `bin/rails db:migrate`

## Code Conventions

### Ruby/Rails
- Follow Rails conventions and Omakase styling
- Use `bin/rubocop` for code quality checks
- Models in `app/models/`, controllers in `app/controllers/`
- Use strong parameters in controllers
- Follow RESTful routing patterns

### Database
- Use PostgreSQL-specific features when beneficial
- Prefer database constraints and indexes
- Use Rails migrations for all schema changes

### Security
- Run `bin/brakeman` regularly for security analysis
- Never commit secrets (use Rails credentials or ENV vars)
- The app uses Rails master key for encrypted credentials

## Activity Model Features

### Schedule Types

Activities support four schedule types:
- **flexible** - Can happen anytime (uses suggested days/times)
- **strict** - One-time event with specific start/end times
- **deadline** - Task with a due date
- **recurring_strict** - Recurring events with specific times (Phase 1: Schema complete, Phase 2: Logic in progress)

### Recurring Events (Phase 1: Database Schema)

The Activity model now supports recurring events through these fields:

**Recurrence Pattern:**
- `recurrence_rule` (jsonb) - iCalendar-style RRULE for pattern definition
  - Example: `{"freq": "WEEKLY", "interval": 1, "byday": ["MO"]}` for "every Monday"
  - Example: `{"freq": "MONTHLY", "interval": 1, "byday": ["SU"], "bysetpos": [1]}` for "1st Sunday every month"
- `recurrence_start_date` (date) - When recurrence begins
- `recurrence_end_date` (date, nullable) - When recurrence stops (null = indefinite)
- `occurrence_time_start` (time) - Start time for each occurrence (e.g., "09:00:00")
- `occurrence_time_end` (time) - End time for each occurrence (e.g., "12:00:00")

**Duration:**
- `duration_minutes` (integer) - User's planned participation time
  - For flexible activities: How long the activity takes (replaces hardcoded 60 minutes)
  - For recurring_strict: User's attendance duration (may be less than event duration)
  - Example: Event runs 9am-12pm (3 hours), user attends for 2 hours (duration_minutes: 120)

### Example Usage

```ruby
# Create a recurring yoga class (every Monday 6pm-7pm)
activity = Activity.create!(
  user: current_user,
  name: "Yoga Class",
  schedule_type: "recurring_strict",
  recurrence_rule: {"freq" => "WEEKLY", "interval" => 1, "byday" => ["MO"]},
  recurrence_start_date: Date.current,
  occurrence_time_start: "18:00",
  occurrence_time_end: "19:00",
  duration_minutes: 60
)

# Create recurring event with attendance duration
# Event: Alameda Point Antiques Faire (1st Sunday, 9am-12pm)
# Attendance: 2 hours within that window
activity = Activity.create!(
  user: current_user,
  name: "Alameda Point Antiques Faire",
  schedule_type: "recurring_strict",
  recurrence_rule: {"freq" => "MONTHLY", "interval" => 1, "byday" => ["SU"], "bysetpos" => [1]},
  recurrence_start_date: Date.current,
  occurrence_time_start: "09:00",
  occurrence_time_end: "12:00",
  duration_minutes: 120  # Attend for 2 hours within the 3-hour event window
)
```
