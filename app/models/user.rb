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

  has_one :active_google_account, -> { active }, class_name: "GoogleAccount"

  scope :active, -> { where(archived_at: nil) }

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def to_param
    slug
  end

  # Find or create user from OAuth data
  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first_or_create do |new_user|
      new_user.email = auth.info.email
      new_user.name = auth.info.name
      new_user.password = Devise.friendly_token[0, 20]
    end

    user
  end

  # Create or update Google account from OAuth data (idempotent)
  def update_google_account(auth)
    google_account = google_accounts.find_or_initialize_by(google_id: auth.uid)

    # Always update with latest token data to ensure fresh credentials
    attributes = {
      email: auth.info.email,
      access_token: auth.credentials.token,
      expires_at: auth.credentials.expires_at ? Time.at(auth.credentials.expires_at) : nil
    }

    # Only update refresh_token if we have a new one (Google doesn't always provide it)
    if auth.credentials.refresh_token.present?
      attributes[:refresh_token] = auth.credentials.refresh_token
    end

    google_account.update!(attributes)
    google_account
  end

  private

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
    self.timezone ||= 'America/Los_Angeles' # Default to Pacific Time instead of UTC
  end
end
