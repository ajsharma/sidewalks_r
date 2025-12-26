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

  # Archives the playlist by setting archived_at timestamp
  # @return [Boolean] true if update succeeds, raises exception on failure
  def archive!
    update!(archived_at: Time.current)
  end

  def archive
    update(archived_at: Time.current)
  end

  def to_param
    slug
  end

  # Returns active activities in the playlist ordered by position
  # @return [ActiveRecord::Relation] activities that are not archived, ordered by position
  def ordered_activities
    activities.where(playlist_activities: { archived_at: nil })
              .order("playlist_activities.position ASC")
  end

  def activities_count
    # Use the pre-calculated count from the query if available, otherwise calculate
    return super if defined?(super) && super.present?
    active_activities_count
  rescue NoMethodError
    active_activities_count
  end

  def add_activity(activity, position: nil)
    position ||= (playlist_activities.maximum(:position) || 0) + 1

    playlist_activities.create!(
      activity: activity,
      position: position
    )
  end

  # Removes an activity from the playlist by archiving the association
  # @param activity [Activity] the activity to remove from the playlist
  # @return [Boolean, nil] true if activity was found and archived, nil otherwise
  def remove_activity(activity)
    playlist_activity = playlist_activities.find_by(activity: activity)
    playlist_activity&.update!(archived_at: Time.current)
  end

  private

  def active_activities_count
    activities.where(playlist_activities: { archived_at: nil }).count
  end

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
