class AddDurationToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :duration_minutes, :integer

    # Backfill existing flexible/deadline activities with 60-minute duration
    # (matches current hardcoded behavior in scheduling service)
    reversible do |dir|
      dir.up do
        safety_assured do
          execute <<-SQL
            UPDATE activities
            SET duration_minutes = 60
            WHERE schedule_type IN ('flexible', 'deadline')
              AND duration_minutes IS NULL
          SQL
        end
      end
    end
  end
end
