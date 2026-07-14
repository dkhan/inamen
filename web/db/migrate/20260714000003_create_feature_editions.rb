# frozen_string_literal: true

class CreateFeatureEditions < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_editions do |t|
      t.references :feature, null: false,
                   foreign_key: { to_table: :saved_features, on_delete: :cascade }
      t.string :edition_id, null: false
      t.integer :actual
      t.string :status
      t.datetime :verified_at
      t.string :processing_state, null: false, default: "pending"
      t.text :error

      t.timestamps
    end

    add_index :feature_editions, :edition_id
    add_index :feature_editions, %i[feature_id edition_id], unique: true,
              name: "index_feature_editions_on_feature_and_edition"
  end
end
