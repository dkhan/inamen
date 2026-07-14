# frozen_string_literal: true

class AddFeatureTypeToSavedFeatures < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_features, :feature_type, :string, null: false, default: "bible"
  end
end
