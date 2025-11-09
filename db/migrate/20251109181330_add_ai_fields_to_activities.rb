class AddAiFieldsToActivities < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # AI generation tracking
    add_column :activities, :ai_generated, :boolean, default: false

    # Event source information
    add_column :activities, :source_url, :text
    add_column :activities, :image_url, :text
    add_column :activities, :price, :decimal, precision: 10, scale: 2
    add_column :activities, :organizer, :string

    # AI scheduling suggestions
    add_column :activities, :suggested_months, :integer, array: true, default: []
    add_column :activities, :suggested_days_of_week, :integer, array: true, default: []
    add_column :activities, :suggested_time_of_day, :string

    # Categorization
    add_column :activities, :category_tags, :string, array: true, default: []

    # Indexes for AI-related queries (concurrent to avoid blocking writes)
    add_index :activities, :ai_generated, algorithm: :concurrently
    add_index :activities, :category_tags, using: :gin, algorithm: :concurrently
    add_index :activities, :suggested_months, using: :gin, algorithm: :concurrently
  end
end
