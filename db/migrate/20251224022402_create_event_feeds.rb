class CreateEventFeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :event_feeds do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :feed_type, default: "rss"
      t.boolean :active, default: true
      t.datetime :last_fetched_at
      t.text :last_error
      t.integer :event_count, default: 0

      t.timestamps
    end

    add_index :event_feeds, :active
    add_index :event_feeds, :last_fetched_at
  end
end
