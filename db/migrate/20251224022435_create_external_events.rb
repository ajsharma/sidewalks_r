class CreateExternalEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :external_events do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.string :location
      t.string :venue
      t.text :source_url, null: false
      t.decimal :price, precision: 10, scale: 2
      t.string :price_details
      t.string :organizer
      t.string :category_tags, array: true, default: []
      t.string :external_id
      t.references :event_feed, null: false, foreign_key: true
      t.datetime :archived_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :external_events, :start_time
    add_index :external_events, :category_tags, using: :gin
    add_index :external_events, :archived_at
    add_index :external_events, [ :event_feed_id, :external_id ], unique: true
  end
end
