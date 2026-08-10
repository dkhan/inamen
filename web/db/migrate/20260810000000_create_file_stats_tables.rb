# frozen_string_literal: true

class CreateFileStatsTables < ActiveRecord::Migration[8.1]
  def change
    create_table :file_stat_snapshots do |t|
      t.references :edition, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :edition_short_name, null: false
      t.string :source_checksum, null: false
      t.string :publisher_revision, null: false
      t.string :explorer_cache_version, null: false
      t.integer :total, null: false
      t.integer :character_count, null: false
      t.integer :seven_power, null: false
      t.json :rows, null: false, default: []

      t.timestamps
    end

    create_table :file_stat_nodes do |t|
      t.references :file_stat_snapshot, null: false, foreign_key: { on_delete: :cascade }
      t.string :node_id, null: false
      t.string :parent_id
      t.string :level, null: false
      t.string :label, null: false
      t.string :testament
      t.string :book
      t.integer :chapter
      t.integer :verse
      t.integer :word_count, null: false, default: 0
      t.integer :number_count, null: false, default: 0
      t.integer :division_count, null: false, default: 0
      t.integer :character_count, null: false, default: 0
      t.integer :letter_count, null: false, default: 0
      t.integer :digit_count, null: false, default: 0
      t.integer :other_count, null: false, default: 0

      t.timestamps
    end
    add_index :file_stat_nodes, %i[file_stat_snapshot_id node_id], unique: true
    add_index :file_stat_nodes, %i[file_stat_snapshot_id parent_id]

    create_table :file_stat_categories do |t|
      t.references :file_stat_snapshot, null: false, foreign_key: { on_delete: :cascade }
      t.string :node_id, null: false
      t.string :category, null: false
      t.string :subcategory, null: false
      t.integer :count, null: false, default: 0

      t.timestamps
    end
    add_index :file_stat_categories, %i[file_stat_snapshot_id node_id]

    create_table :file_stat_characters do |t|
      t.references :file_stat_snapshot, null: false, foreign_key: { on_delete: :cascade }
      t.string :node_id, null: false
      t.string :category, null: false
      t.string :char, null: false
      t.string :codepoint, null: false
      t.string :name, null: false
      t.integer :count, null: false, default: 0

      t.timestamps
    end
    add_index :file_stat_characters, %i[file_stat_snapshot_id node_id]
  end
end
