# frozen_string_literal: true

class CreateEditions < ActiveRecord::Migration[8.1]
  def change
    create_table :editions do |t|
      t.string :short_name, null: false
      t.string :name, null: false
      t.string :corpus_type, null: false, default: "bible"
      t.string :source_path, null: false
      t.string :source_filename, null: false
      t.string :source_checksum, null: false
      t.integer :byte_size, null: false
      t.json :metadata, null: false, default: {}
      t.datetime :imported_at, null: false
      t.timestamps
    end

    add_index :editions, :short_name, unique: true
  end
end
