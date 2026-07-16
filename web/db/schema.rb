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

ActiveRecord::Schema[8.1].define(version: 2026_07_16_000000) do
  create_table "editions", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.string "corpus_type", default: "bible", null: false
    t.datetime "created_at", null: false
    t.datetime "imported_at", null: false
    t.json "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "short_name", null: false
    t.string "source_checksum", null: false
    t.string "source_filename", null: false
    t.string "source_path", null: false
    t.datetime "updated_at", null: false
    t.index ["short_name"], name: "index_editions_on_short_name", unique: true
  end

  create_table "feature_editions", force: :cascade do |t|
    t.integer "actual"
    t.datetime "created_at", null: false
    t.string "edition_id", null: false
    t.text "error"
    t.integer "feature_id", null: false
    t.string "processing_state", default: "pending", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["edition_id"], name: "index_feature_editions_on_edition_id"
    t.index ["feature_id", "edition_id"], name: "index_feature_editions_on_feature_and_edition", unique: true
    t.index ["feature_id"], name: "index_feature_editions_on_feature_id"
  end

  create_table "saved_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", default: "Saved from Discover", null: false
    t.json "details", default: [], null: false
    t.integer "expected_count", null: false
    t.string "feature_type", default: "bible", null: false
    t.string "from_feature"
    t.string "kjvcode_url"
    t.string "language", default: "en", null: false
    t.string "mode", default: "word_count", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "original_edition_id", null: false
    t.string "scope_label", null: false
    t.json "search_phrases", default: {}, null: false
    t.json "search_selection", default: {}, null: false
    t.string "unit", default: "occurrences", null: false
    t.datetime "updated_at", null: false
    t.index ["language"], name: "index_saved_features_on_language"
    t.index ["name"], name: "index_saved_features_on_name"
    t.index ["original_edition_id"], name: "index_saved_features_on_original_edition_id"
  end

  add_foreign_key "feature_editions", "saved_features", column: "feature_id", on_delete: :cascade
end
