class AddIndexToExternalEventsRawData < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :external_events, :raw_data, using: :gin, comment: "Enable fast searches within raw feed data", algorithm: :concurrently
  end
end
