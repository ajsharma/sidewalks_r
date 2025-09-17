# Join model connecting playlists and activities.
# Handles position ordering and archiving of playlist items.
class PlaylistActivity < ApplicationRecord
  belongs_to :playlist
  belongs_to :activity

  validates :playlist_id, uniqueness: { scope: :activity_id }

  scope :active, -> { where(archived_at: nil) }


  def archive!
    update!(archived_at: Time.current)
  end

  def archive
    update(archived_at: Time.current)
  end
end
