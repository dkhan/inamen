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

ActiveRecord::Schema[8.1].define(version: 2026_07_11_201345) do
  create_table "saved_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", default: "Saved from Discover", null: false
    t.json "details", default: [], null: false
    t.string "edition_id", null: false
    t.integer "expected_count", null: false
    t.string "from_feature"
    t.string "kjvcode_url"
    t.string "mode", default: "word_count", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "saved_actual_count", null: false
    t.string "scope_label", null: false
    t.json "search_phrases", default: {}, null: false
    t.json "search_selection", default: {}, null: false
    t.string "unit", default: "occurrences", null: false
    t.datetime "updated_at", null: false
    t.index ["edition_id"], name: "index_saved_features_on_edition_id"
    t.index ["name"], name: "index_saved_features_on_name"
  end
end
