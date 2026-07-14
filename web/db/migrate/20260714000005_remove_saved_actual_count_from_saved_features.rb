# frozen_string_literal: true

# Actual counts now live in feature_editions (see the backfill migration).
class RemoveSavedActualCountFromSavedFeatures < ActiveRecord::Migration[8.1]
  def change
    remove_column :saved_features, :saved_actual_count, :integer, null: false
  end
end
