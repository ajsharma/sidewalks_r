# frozen_string_literal: true

# Service object to handle recurrence pattern matching logic.
# Extracts pattern matching complexity from Activity model.
class RecurrencePatternMatcher
  attr_reader :recurrence_start_date, :recurrence_end_date

  def initialize(recurrence_start_date, recurrence_end_date = nil)
    @recurrence_start_date = recurrence_start_date
    @recurrence_end_date = recurrence_end_date
  end

  # Check if a date matches the given recurrence pattern
  def matches?(date, rule)
    return false if date < recurrence_start_date
    return false if recurrence_end_date && date > recurrence_end_date

    freq = rule[:freq] || rule["freq"]
    interval = (rule[:interval] || rule["interval"] || 1).to_i

    case freq
    when "DAILY"
      matches_daily?(date, interval)
    when "WEEKLY"
      matches_weekly?(date, interval, rule[:byday] || rule["byday"])
    when "MONTHLY"
      matches_monthly?(date, interval, rule)
    when "YEARLY"
      matches_yearly?(date, interval)
    else
      false
    end
  end

  private

  def matches_daily?(date, interval)
    days_since_start = (date - recurrence_start_date).to_i
    (days_since_start % interval).zero?
  end

  def matches_weekly?(date, interval, byday)
    weeks_since_start = ((date - recurrence_start_date).to_i / 7)
    return false unless (weeks_since_start % interval).zero?

    return true if byday.blank?

    day_abbr = date.strftime("%^a")[0..1]
    byday.map(&:to_s).include?(day_abbr)
  end

  def matches_monthly?(date, interval, rule)
    date_year = date.year
    date_month = date.month
    date_day = date.day

    months_since_start = (date_year - recurrence_start_date.year) * 12 +
                         (date_month - recurrence_start_date.month)
    return false unless (months_since_start % interval).zero?

    bymonthday = rule[:bymonthday] || rule["bymonthday"]
    return bymonthday.map(&:to_i).include?(date_day) if bymonthday.present?

    byday = rule[:byday] || rule["byday"]
    bysetpos = rule[:bysetpos] || rule["bysetpos"]

    if byday.present? && bysetpos.present?
      day_abbr = date.strftime("%^a")[0..1]
      return false unless byday.map(&:to_s).include?(day_abbr)

      occurrence_in_month = ((date_day - 1) / 7) + 1
      days_in_month = Date.civil(date_year, date_month, -1).day
      occurrence_from_end = -(((days_in_month - date_day) / 7) + 1)

      bysetpos.map(&:to_i).each do |pos|
        return true if pos.positive? && pos == occurrence_in_month
        return true if pos.negative? && pos == occurrence_from_end
      end

      return false
    end

    true
  end

  def matches_yearly?(date, interval)
    date_year = date.year
    years_since_start = date_year - recurrence_start_date.year
    return false unless (years_since_start % interval).zero?

    date.month == recurrence_start_date.month &&
    date.day == recurrence_start_date.day
  end
end
