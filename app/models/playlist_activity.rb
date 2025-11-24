# Join model connecting playlists and activities.
# Handles position ordering and archiving of playlist items.
# == Schema Information
#
# Table name: playlist_activities
#
#  id          :bigint           not null, primary key
#  archived_at :datetime
#  position    :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  activity_id :bigint           not null
#  playlist_id :bigint           not null
#
# Indexes
#
#  index_playlist_activities_on_activity_id                  (activity_id)
#  index_playlist_activities_on_playlist_id                  (playlist_id)
#  index_playlist_activities_on_playlist_id_and_activity_id  (playlist_id,activity_id) UNIQUE
#  index_playlist_activities_on_playlist_id_and_position     (playlist_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (activity_id => activities.id)
#  fk_rails_...  (playlist_id => playlists.id)
#
class PlaylistActivity < ApplicationRecord
  belongs_to :playlist
  belongs_to :activity

  validates :playlist_id, uniqueness: { scope: :activity_id }

  scope :active, -> { where(archived_at: nil) }

  # Archives the playlist-activity association by setting archived_at timestamp
  # @return [Boolean] true if update succeeds, raises exception on failure
  def archive!
    update!(archived_at: Time.current)
  end

  # Archives the playlist-activity association by setting archived_at timestamp (safe version)
  # @return [Boolean] true if update succeeds, false otherwise
  def archive
    update(archived_at: Time.current)
  end
end
