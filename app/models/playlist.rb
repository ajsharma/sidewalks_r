# Model representing a collection of activities organized by users.
# Handles activity ordering, management, and archiving functionality.
class Playlist < ApplicationRecord
  belongs_to :user
  has_many :playlist_activities, dependent: :destroy
  has_many :activities, through: :playlist_activities

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :active, -> { where(archived_at: nil) }
  scope :owned_by, ->(user) { where(user: user) }

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def archive
    update(archived_at: Time.current)
  end

  def to_param
    slug
  end

  def ordered_activities
    activities.where(playlist_activities: { archived_at: nil })
              .order("playlist_activities.position ASC")
  end

  def add_activity(activity, position: nil)
    position ||= (playlist_activities.maximum(:position) || 0) + 1

    playlist_activities.create!(
      activity: activity,
      position: position
    )
  end

  def remove_activity(activity)
    playlist_activity = playlist_activities.find_by(activity: activity)
    playlist_activity&.update!(archived_at: Time.current)
  end

  private

  def generate_slug
    base_slug = name.parameterize
    counter = 1
    potential_slug = base_slug

    while Playlist.where(slug: potential_slug).exists?
      potential_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = potential_slug
  end
end
