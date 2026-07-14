# frozen_string_literal: true

class RenameSavedFeaturesEditionIdToOriginalEditionId < ActiveRecord::Migration[8.1]
  def change
    rename_column :saved_features, :edition_id, :original_edition_id
  end
end
