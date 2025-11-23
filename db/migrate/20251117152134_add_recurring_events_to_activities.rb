class AddRecurringEventsToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :recurrence_rule, :jsonb
    add_column :activities, :recurrence_start_date, :date
    add_column :activities, :recurrence_end_date, :date
    add_column :activities, :occurrence_time_start, :time
    add_column :activities, :occurrence_time_end, :time

    # Add indexes (safe for development with small dataset)
    safety_assured do
      add_index :activities, :recurrence_rule, using: :gin
      add_index :activities, :recurrence_start_date
      add_index :activities, :recurrence_end_date
    end
  end
end
