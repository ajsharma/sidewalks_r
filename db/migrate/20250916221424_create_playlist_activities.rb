class CreatePlaylistActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :playlist_activities do |t|
      t.references :playlist, null: false, foreign_key: true                 # Playlist containing the activity
      t.references :activity, null: false, foreign_key: true                 # Activity in the playlist
      t.integer :position                                                     # Order within playlist
      t.datetime :archived_at                                                 # Soft delete from playlist

      t.timestamps
    end

    add_index :playlist_activities, [ :playlist_id, :activity_id ], unique: true # One activity per playlist
    add_index :playlist_activities, [ :playlist_id, :position ]                # Ordered activities in playlist
  end
end
