class CreateAiActivitySuggestions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :ai_activity_suggestions do |t|
      # User association
      t.references :user, null: false, foreign_key: true, index: false

      # Input tracking
      t.string :input_type, null: false, default: 'text' # enum: text, url
      t.text :input_text
      t.text :source_url

      # AI Processing metadata
      t.string :model_used
      t.integer :processing_time_ms
      t.decimal :confidence_score, precision: 5, scale: 2

      # JSONB fields for flexibility
      t.jsonb :extracted_metadata, default: {}
      t.jsonb :api_request, default: {}
      t.jsonb :api_response, default: {}
      t.jsonb :suggested_data, default: {}
      t.jsonb :user_edits, default: {}

      # Outcome tracking
      t.references :final_activity, foreign_key: { to_table: :activities }, index: false
      t.boolean :accepted, default: false
      t.datetime :accepted_at

      # Processing status
      t.string :status, default: 'pending' # pending, processing, completed, failed
      t.text :error_message

      t.timestamps
    end

    # Indexes for common queries (concurrent to avoid blocking writes)
    add_index :ai_activity_suggestions, :user_id, algorithm: :concurrently
    add_index :ai_activity_suggestions, :final_activity_id, algorithm: :concurrently
    add_index :ai_activity_suggestions, :status, algorithm: :concurrently
    add_index :ai_activity_suggestions, :input_type, algorithm: :concurrently
    add_index :ai_activity_suggestions, :accepted, algorithm: :concurrently
    add_index :ai_activity_suggestions, :created_at, algorithm: :concurrently
    add_index :ai_activity_suggestions, [:user_id, :created_at], algorithm: :concurrently
  end
end
