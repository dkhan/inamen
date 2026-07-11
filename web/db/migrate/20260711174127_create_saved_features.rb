class CreateSavedFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_features do |t|
      t.string :name, null: false
      t.string :edition_id, null: false
      t.string :scope_label, null: false
      t.string :unit, null: false, default: "occurrences"
      t.integer :expected_count, null: false
      t.integer :saved_actual_count, null: false
      t.string :mode, null: false, default: "word_count"
      t.json :search_selection, null: false, default: {}
      t.json :search_phrases, null: false, default: {}
      t.string :from_feature
      t.json :details, null: false, default: []

      t.timestamps
    end

    add_index :saved_features, :name
    add_index :saved_features, :edition_id
  end
end
