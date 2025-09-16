class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :omniauthable,
         omniauth_providers: [:google_oauth2]

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  has_many :google_accounts, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :playlists, dependent: :destroy

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

  # Find or create user from OAuth data
  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = Devise.friendly_token[0, 20]
    end
  end

  # Create or update Google account from OAuth data
  def update_google_account(auth)
    google_account = google_accounts.find_or_initialize_by(google_id: auth.uid)

    google_account.update!(
      email: auth.info.email,
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at: auth.credentials.expires_at ? Time.at(auth.credentials.expires_at) : nil
    )

    google_account
  end
end
