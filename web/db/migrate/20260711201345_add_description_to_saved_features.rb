class AddDescriptionToSavedFeatures < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_features, :description, :string, null: false, default: "Saved from Discover"
  end
end
