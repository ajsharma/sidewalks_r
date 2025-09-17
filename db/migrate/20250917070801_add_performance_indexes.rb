class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Core activity queries - most common filtering patterns
    add_index :activities, [:user_id, :schedule_type, :archived_at],
              name: 'index_activities_on_user_schedule_archived',
              comment: 'Optimize queries for user activities by schedule type and archived status'

    # Deadline-based activity searches
    add_index :activities, [:deadline],
              where: "deadline IS NOT NULL",
              name: 'index_activities_on_deadline_not_null',
              comment: 'Optimize deadline-based activity queries'

    # Google account token refresh queries
    add_index :google_accounts, [:user_id, :expires_at],
              name: 'index_google_accounts_on_user_expires',
              comment: 'Optimize token refresh and expiration queries'

    # User timezone queries for scheduling
    add_index :users, [:timezone],
              name: 'index_users_on_timezone',
              comment: 'Optimize timezone-based user grouping and scheduling'

    # Activity frequency and max frequency queries
    add_index :activities, [:max_frequency_days],
              where: "max_frequency_days IS NOT NULL",
              name: 'index_activities_on_max_frequency',
              comment: 'Optimize frequency-based activity filtering'
  end
end
