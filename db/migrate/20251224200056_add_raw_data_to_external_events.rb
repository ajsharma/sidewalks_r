class AddRawDataToExternalEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :external_events, :raw_data, :jsonb, comment: "Raw RSS/Atom feed entry data for reprocessing"
  end
end
