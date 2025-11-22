class AddCommentsToRecurringActivityColumns < ActiveRecord::Migration[8.1]
  def change
    change_column_comment :activities, :recurrence_rule,
      "iCalendar RRULE format (RFC 5545) defining recurrence pattern (DAILY, WEEKLY, MONTHLY, YEARLY) with interval, byday, bymonthday, bysetpos"

    change_column_comment :activities, :recurrence_start_date,
      "First date when the recurring event begins"

    change_column_comment :activities, :recurrence_end_date,
      "Optional last date for recurrence (null for indefinite recurrence)"

    change_column_comment :activities, :occurrence_time_start,
      "Time of day when each occurrence starts (for recurring_strict schedule type)"

    change_column_comment :activities, :occurrence_time_end,
      "Time of day when each occurrence ends (for recurring_strict schedule type)"
  end
end
