# frozen_string_literal: true

# Move each existing feature's actual count into a FeatureEdition record for the
# edition it was originally verified against. Runs before saved_actual_count is
# removed. Uses raw SQL so it is independent of the evolving app models.
class BackfillFeatureEditionsFromSavedFeatures < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL.squish)
      INSERT INTO feature_editions
        (feature_id, edition_id, actual, status, verified_at, processing_state, created_at, updated_at)
      SELECT
        id,
        original_edition_id,
        saved_actual_count,
        CASE WHEN saved_actual_count = expected_count THEN 'match' ELSE 'miss' END,
        COALESCE(updated_at, CURRENT_TIMESTAMP),
        'verified',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM saved_features
      WHERE id NOT IN (SELECT feature_id FROM feature_editions)
    SQL
  end

  def down
    execute("DELETE FROM feature_editions")
  end
end
