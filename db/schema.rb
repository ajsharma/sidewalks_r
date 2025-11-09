# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_09_181330) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activities", force: :cascade do |t|
    t.boolean "ai_generated", default: false
    t.datetime "archived_at"
    t.string "category_tags", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "deadline"
    t.text "description"
    t.datetime "end_time"
    t.text "image_url"
    t.text "links"
    t.integer "max_frequency_days"
    t.string "name", null: false
    t.string "organizer"
    t.decimal "price", precision: 10, scale: 2
    t.string "schedule_type", default: "flexible"
    t.string "slug", null: false
    t.text "source_url"
    t.datetime "start_time"
    t.integer "suggested_days_of_week", default: [], array: true
    t.integer "suggested_months", default: [], array: true
    t.string "suggested_time_of_day"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ai_generated"], name: "index_activities_on_ai_generated"
    t.index ["category_tags"], name: "index_activities_on_category_tags", using: :gin
    t.index ["deadline"], name: "index_activities_on_deadline_not_null", where: "(deadline IS NOT NULL)", comment: "Optimize deadline-based activity queries"
    t.index ["max_frequency_days"], name: "index_activities_on_max_frequency", where: "(max_frequency_days IS NOT NULL)", comment: "Optimize frequency-based activity filtering"
    t.index ["schedule_type"], name: "index_activities_on_schedule_type"
    t.index ["slug"], name: "index_activities_on_slug", unique: true
    t.index ["suggested_months"], name: "index_activities_on_suggested_months", using: :gin
    t.index ["user_id", "archived_at"], name: "index_activities_on_user_id_and_archived_at"
    t.index ["user_id", "schedule_type", "archived_at"], name: "index_activities_on_user_schedule_archived", comment: "Optimize queries for user activities by schedule type and archived status"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "ai_activity_suggestions", force: :cascade do |t|
    t.boolean "accepted", default: false
    t.datetime "accepted_at"
    t.jsonb "api_request", default: {}
    t.jsonb "api_response", default: {}
    t.decimal "confidence_score", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.text "error_message"
    t.jsonb "extracted_metadata", default: {}
    t.bigint "final_activity_id"
    t.text "input_text"
    t.string "input_type", default: "text", null: false
    t.string "model_used"
    t.integer "processing_time_ms"
    t.text "source_url"
    t.string "status", default: "pending"
    t.jsonb "suggested_data", default: {}
    t.datetime "updated_at", null: false
    t.jsonb "user_edits", default: {}
    t.bigint "user_id", null: false
    t.index ["accepted"], name: "index_ai_activity_suggestions_on_accepted"
    t.index ["created_at"], name: "index_ai_activity_suggestions_on_created_at"
    t.index ["final_activity_id"], name: "index_ai_activity_suggestions_on_final_activity_id"
    t.index ["input_type"], name: "index_ai_activity_suggestions_on_input_type"
    t.index ["status"], name: "index_ai_activity_suggestions_on_status"
    t.index ["user_id", "created_at"], name: "index_ai_activity_suggestions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_ai_activity_suggestions_on_user_id"
  end

  create_table "google_accounts", force: :cascade do |t|
    t.text "access_token"
    t.datetime "archived_at"
    t.text "calendar_list"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at"
    t.string "google_id", null: false
    t.text "refresh_token"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["google_id"], name: "index_google_accounts_on_google_id"
    t.index ["user_id", "expires_at"], name: "index_google_accounts_on_user_expires", comment: "Optimize token refresh and expiration queries"
    t.index ["user_id", "google_id"], name: "index_google_accounts_on_user_id_and_google_id", unique: true
    t.index ["user_id"], name: "index_google_accounts_on_user_id"
  end

  create_table "playlist_activities", force: :cascade do |t|
    t.bigint "activity_id", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.bigint "playlist_id", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index ["activity_id"], name: "index_playlist_activities_on_activity_id"
    t.index ["playlist_id", "activity_id"], name: "index_playlist_activities_on_playlist_id_and_activity_id", unique: true
    t.index ["playlist_id", "position"], name: "index_playlist_activities_on_playlist_id_and_position"
    t.index ["playlist_id"], name: "index_playlist_activities_on_playlist_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["slug"], name: "index_playlists_on_slug", unique: true
    t.index ["user_id", "archived_at"], name: "index_playlists_on_user_id_and_archived_at"
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "slug", null: false
    t.string "timezone", default: "UTC"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["timezone"], name: "index_users_on_timezone", comment: "Optimize timezone-based user grouping and scheduling"
  end

  add_foreign_key "activities", "users"
  add_foreign_key "ai_activity_suggestions", "activities", column: "final_activity_id"
  add_foreign_key "ai_activity_suggestions", "users"
  add_foreign_key "google_accounts", "users"
  add_foreign_key "playlist_activities", "activities"
  add_foreign_key "playlist_activities", "playlists"
  add_foreign_key "playlists", "users"
end
