# frozen_string_literal: true

# One saved feature's verification result against one edition. Records the actual
# count, MATCH/MISS status, and processing state. Unique per (feature, edition).
class FeatureEdition < ApplicationRecord
  STATUS_MATCH = "match"
  STATUS_MISS = "miss"

  belongs_to :saved_feature, foreign_key: :feature_id, inverse_of: :feature_editions

  enum :status, { match: STATUS_MATCH, miss: STATUS_MISS }, prefix: :status
  enum :processing_state,
       { pending: "pending", processing: "processing", verified: "verified", failed: "failed" },
       prefix: :processing, default: :pending

  validates :edition_id, presence: true
  validates :feature_id, uniqueness: { scope: :edition_id }

  def match?
    status_match?
  end
end
