class CreateGoogleAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :google_accounts do |t|
      t.references :user, null: false, foreign_key: true                    # User who owns this Google account
      t.string :email, null: false                                          # Google account email
      t.string :google_id, null: false                                      # Google's unique user ID
      t.text :access_token                                                   # OAuth access token (encrypted)
      t.text :refresh_token                                                  # OAuth refresh token (encrypted)
      t.datetime :expires_at                                                 # When access token expires
      t.text :calendar_list                                                  # JSON list of available calendars
      t.datetime :archived_at                                                # Soft delete timestamp

      t.timestamps
    end

    add_index :google_accounts, [:user_id, :google_id], unique: true       # One Google account per user+google_id combo
    add_index :google_accounts, :google_id                                  # Fast lookup by Google ID
  end
end
