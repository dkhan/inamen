# frozen_string_literal: true

class AddLanguageToSavedFeatures < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_features, :language, :string, null: false, default: "en"
    add_index :saved_features, :language
  end
end
