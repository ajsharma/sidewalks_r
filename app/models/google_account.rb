# Model representing a user's Google account integration.
# Handles OAuth tokens, calendar access, and account management.
class GoogleAccount < ApplicationRecord
  belongs_to :user

  # Encrypt sensitive OAuth tokens
  encrypts :access_token
  encrypts :refresh_token

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :google_id, presence: true, uniqueness: { scope: :user_id }

  scope :active, -> { where(archived_at: nil) }

  def archived?
    archived_at.present?
  end

  # Archives the Google account by setting archived_at timestamp
  # @return [Boolean] true if update succeeds, raises exception on failure
  def archive!
    update!(archived_at: Time.current)
  end

  # Archives the Google account by setting archived_at timestamp (safe version)
  # @return [Boolean] true if update succeeds, false otherwise
  def archive
    update(archived_at: Time.current)
  end

  def token_expired?
    expires_at.present? && expires_at <= Time.current
  end

  # Parses and returns Google calendars from JSON storage
  # @return [Array] array of calendar objects, empty array if none or parse error
  def calendars
    return [] unless calendar_list.present?

    JSON.parse(calendar_list)
  rescue JSON::ParserError
    []
  end

  # Sets Google calendars by converting data to JSON
  # @param calendar_data [Object] calendar data to be converted to JSON and stored
  # @return [String] the JSON string that was stored
  def calendars=(calendar_data)
    self.calendar_list = calendar_data.to_json
  end

  def needs_refresh?
    token_expired? || access_token.blank?
  end
end
