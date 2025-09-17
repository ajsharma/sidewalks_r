class CreatePlaylists < ActiveRecord::Migration[8.0]
  def change
    create_table :playlists do |t|
      t.references :user, null: false, foreign_key: true                     # Playlist creator/owner
      t.string :name, null: false                                            # Playlist name
      t.string :slug, null: false                                            # URL-friendly identifier
      t.text :description                                                     # Playlist description
      t.datetime :archived_at                                                 # Soft delete timestamp

      t.timestamps
    end

    add_index :playlists, :slug, unique: true                               # Unique slug across all playlists
    add_index :playlists, [ :user_id, :archived_at ]                          # User's active playlists
  end
end
