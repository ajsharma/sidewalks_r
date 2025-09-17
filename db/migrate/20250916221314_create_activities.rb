class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.references :user, null: false, foreign_key: true                     # Creator of the activity
      t.string :name, null: false                                            # Activity name/title
      t.string :slug, null: false                                            # URL-friendly identifier
      t.text :description                                                     # Activity description
      t.text :links                                                           # JSON array of related links
      t.string :schedule_type, default: 'flexible'                           # 'strict', 'flexible', 'deadline'
      t.datetime :start_time                                                  # For strict schedules
      t.datetime :end_time                                                    # For strict schedules
      t.datetime :deadline                                                    # For deadline-based activities
      t.integer :max_frequency_days                                           # Minimum days between repeats
      t.datetime :archived_at                                                 # Soft delete timestamp

      t.timestamps
    end

    add_index :activities, :slug, unique: true                               # Unique slug across all activities
    add_index :activities, [ :user_id, :archived_at ]                          # User's active activities
    add_index :activities, :schedule_type                                     # Filter by schedule type
  end
end
