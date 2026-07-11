class AddNotesAndKjvcodeUrlToSavedFeatures < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_features, :notes, :text
    add_column :saved_features, :kjvcode_url, :string
  end
end
