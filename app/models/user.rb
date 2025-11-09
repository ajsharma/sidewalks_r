# User model for authentication and profile management.
# Handles OAuth integration, timezone settings, and activity associations.
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :omniauthable,
         omniauth_providers: [ :google_oauth2 ]

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_blank: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  before_validation :set_default_timezone, on: :create

  has_many :google_accounts, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_many :ai_suggestions, class_name: 'AiActivitySuggestion', dependent: :destroy

  has_one :active_google_account, -> { active }, class_name: "GoogleAccount"

  scope :active, -> { where(archived_at: nil) }

  def archived?
    archived_at.present?
  end

  # Archives the user by setting archived_at timestamp
  # @return [Boolean] true if update succeeds, raises exception on failure
  def archive!
    update!(archived_at: Time.current)
  end

  # Archives the user by setting archived_at timestamp (safe version)
  # @return [Boolean] true if update succeeds, false otherwise
  def archive
    update(archived_at: Time.current)
  end

  # Returns the slug for URL parameter usage
  # @return [String] the user's slug for use in URLs
  def to_param
    slug
  end

  # Find or create user from OAuth data
  def self.from_omniauth(auth)
    auth_info = auth.info
    email = auth_info.email

    user = where(email: email).first_or_create do |new_user|
      new_user.email = email
      new_user.name = auth_info.name
      new_user.password = Devise.friendly_token[0, 20]
    end

    user
  end

  # Create or update Google account from OAuth data (idempotent)
  def update_google_account(auth)
    google_account = google_accounts.find_or_initialize_by(google_id: auth.uid)

    attributes = build_google_account_attributes(auth)
    google_account.update!(attributes)
    google_account
  end

  private

  def build_google_account_attributes(auth)
    credentials = auth.credentials
    expires_at = credentials.expires_at
    refresh_token = credentials.refresh_token

    attributes = {
      email: auth.info.email,
      access_token: credentials.token,
      expires_at: expires_at ? Time.at(expires_at) : nil
    }

    # Only update refresh_token if we have a new one (Google doesn't always provide it)
    if refresh_token.present?
      attributes[:refresh_token] = refresh_token
    end

    attributes
  end

  def generate_slug
    base_slug = name.parameterize
    counter = 1
    potential_slug = base_slug

    while User.where(slug: potential_slug).exists?
      potential_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = potential_slug
  end

  def set_default_timezone
    # Try to detect timezone from browser or use a reasonable default for US users
    self.timezone ||= "Pacific Time (US & Canada)" # Default to Pacific Time instead of UTC
  end
end
