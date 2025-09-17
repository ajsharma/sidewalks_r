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

  def archive!
    update!(archived_at: Time.current)
  end

  def token_expired?
    expires_at.present? && expires_at <= Time.current
  end

  def calendars
    return [] unless calendar_list.present?

    JSON.parse(calendar_list)
  rescue JSON::ParserError
    []
  end

  def calendars=(calendar_data)
    self.calendar_list = calendar_data.to_json
  end

  def needs_refresh?
    token_expired? || access_token.blank?
  end
end
