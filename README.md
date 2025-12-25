# Sidewalks

A modern Rails 8 application for intelligent activity scheduling and management. Sidewalks helps users organize their activities with flexible scheduling options, create custom playlists, and integrate with Google Calendar for seamless time management.

## Features

- **Smart Activity Management**: Create and manage activities with three schedule types:
  - **Strict**: Fixed time slots with start and end times
  - **Flexible**: Activities without fixed times but with frequency constraints
  - **Deadline-based**: Tasks with completion deadlines

- **Playlist Organization**: Group activities into custom playlists for better organization and workflow management

- **Google Calendar Integration**: OAuth2 authentication and calendar synchronization for seamless scheduling

- **User Authentication**: Secure authentication via Devise with Google OAuth2 support

- **Timezone Support**: Multi-timezone support for accurate scheduling across locations

- **Activity Archiving**: Soft-delete functionality for activities, playlists, and user accounts

- **Health Monitoring**: Comprehensive health check endpoints for application and dependency monitoring

## Tech Stack

### Core Framework
- **Rails 8.0.2** - Modern Rails with latest conventions
- **PostgreSQL** - Robust relational database
- **Puma** - High-performance web server
- **Ruby 3.4.5** - Latest Ruby version

### Frontend
- **Tailwind CSS** - Utility-first CSS framework
- **Turbo Rails** - SPA-like page acceleration
- **Stimulus Rails** - Modest JavaScript framework
- **Importmap Rails** - ES6 modules without bundling

### Background Processing & Caching
- **Solid Queue** - Database-backed job queue
- **Solid Cache** - Database-backed caching
- **Solid Cable** - Database-backed Action Cable

### Development & Quality Tools
- **RuboCop Rails Omakase** - Code styling and linting
- **Brakeman** - Security vulnerability scanner
- **Bundler Audit** - Gem security auditing
- **Reek** - Code smell detection
- **Rails Best Practices** - Rails-specific analysis
- **Strong Migrations** - Safe database migrations
- **Bullet** - N+1 query detection
- **SimpleCov** - Code coverage analysis
- **Axe Core Capybara** - Accessibility testing

## Prerequisites

- Ruby 3.4.5
- PostgreSQL 14+
- Node.js (for JavaScript dependencies)
- Git

## Installation

### 1. Clone the repository

```bash
git clone <repository-url>
cd sidewalks_r
```

### 2. Run the setup script

The setup script handles all dependencies, database creation, and initial configuration:

```bash
bin/setup
```

This will:
- Install Ruby gem dependencies
- Install JavaScript dependencies
- Create and migrate the database
- Seed initial data

### 3. Configure environment variables

Set up your Google OAuth credentials:

```bash
EDITOR=vim bin/rails credentials:edit
```

Add your Google OAuth credentials:

```yaml
google:
  client_id: YOUR_GOOGLE_CLIENT_ID
  client_secret: YOUR_GOOGLE_CLIENT_SECRET
```

## Development

### Start the development server

```bash
bin/dev
```

This starts both the Rails server and Tailwind CSS watcher via Procfile.dev.

The application will be available at `http://localhost:3000`

### Quick Development Pipeline

Run the full development pipeline (setup, tests, security, quality checks):

```bash
bin/go                 # Run all checks with full output
bin/go --errors-only   # Run all checks showing only section headers and errors (quieter output)
```

The `--errors-only` flag is useful for quick validation as it suppresses successful command output while still showing failures.

### Database Operations

```bash
bin/rails db:migrate        # Run pending migrations
bin/rails db:rollback       # Rollback last migration
bin/rails db:reset          # Drop, create, migrate, and seed
bin/rails db:seed           # Load seed data
```

### Rails Console

```bash
bin/rails console
```

## Testing

### Run the full test suite

```bash
bin/rails test
```

### Run specific tests

```bash
bin/rails test test/models/activity_test.rb
bin/rails test test/controllers/activities_controller_test.rb
```

### System tests

```bash
bin/rails test:system
```

### Code Coverage

Test coverage reports are generated automatically with SimpleCov when running tests. View the report at `coverage/index.html`.

## Code Quality

### Linting and Style

```bash
bin/rubocop              # Check code style
bin/rubocop -a           # Auto-correct issues
```

### Security Analysis

```bash
bin/brakeman                          # Rails security scanner
bundle exec bundle-audit --update     # Check for vulnerable gems
bin/rails importmap:audit             # Check JavaScript dependencies
```

### Code Quality Analysis

```bash
bundle exec reek .                    # Detect code smells
bundle exec rails_best_practices .    # Rails-specific best practices
```

## Project Structure

```
app/
├── controllers/        # Application controllers
│   ├── activities_controller.rb
│   ├── activity_scheduling_controller.rb
│   ├── playlists_controller.rb
│   └── health_controller.rb
├── models/            # ActiveRecord models
│   ├── user.rb
│   ├── activity.rb
│   ├── playlist.rb
│   ├── playlist_activity.rb
│   └── google_account.rb
├── views/             # ERB templates
├── javascript/        # Stimulus controllers
└── assets/           # Images, stylesheets

config/
├── routes.rb         # Application routes
├── database.yml      # Database configuration
└── environments/     # Environment configs

db/
├── migrate/          # Database migrations
└── schema.rb         # Current schema

test/
├── models/           # Model tests
├── controllers/      # Controller tests
├── system/           # Integration tests
└── fixtures/         # Test data
```

## Core Models

### User
- Authentication via Devise and Google OAuth2
- Manages activities and playlists
- Timezone-aware scheduling
- Soft-delete archiving

### Activity
- Three schedule types: strict, flexible, deadline
- Frequency management (daily, monthly, yearly, etc.)
- Time validation and business rules
- Associated with users and playlists

### Playlist
- Collection of activities
- Position-based ordering
- Activity count tracking
- Soft-delete archiving

### GoogleAccount
- OAuth token management
- Calendar API integration
- Token refresh handling
- Health monitoring

## Deployment

The application is configured for deployment on **Render.com**.

### Build Process

The `bin/render/build.sh` script handles:
1. Bundle installation
2. Asset precompilation
3. Database migrations

### Environment Variables

Configure the following on your deployment platform:
- `RAILS_MASTER_KEY` - For encrypted credentials
- `DATABASE_URL` - PostgreSQL connection (auto-configured on Render)
- `RAILS_ENV=production`

### Health Checks

The application provides multiple health check endpoints:
- `/health` - Basic health status
- `/health/detailed` - Detailed system information
- `/health/ready` - Readiness probe
- `/health/live` - Liveness probe
- `/up` - Rails default health check

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow Rails conventions and Omakase styling
- Ensure all tests pass (`bin/rails test`)
- Run RuboCop for code quality (`bin/rubocop`)
- Run security checks (`bin/brakeman`)
- Maintain test coverage

## CI/CD Pipeline

The project includes comprehensive CI/CD with:
- **Parallel execution** - Security, linting, and tests run concurrently
- **Security scanning** - Brakeman, bundle-audit, importmap audit
- **Code quality** - RuboCop, Reek, Rails Best Practices
- **Test coverage** - SimpleCov with threshold enforcement
- **Performance monitoring** - Bullet for N+1 query detection

## License

[Add your license here]

## Support

For issues and questions:
- Create an issue in the GitHub repository
- Review existing documentation in `CLAUDE.md`

---

Built with Rails 8 and modern web technologies.
