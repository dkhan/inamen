# frozen_string_literal: true

class FeatureVerificationJob < ApplicationJob
  queue_as :default

  def perform(edition_id, force: false)
    edition = EditionContext.new(edition_id)
    lock_key = FeatureCatalog.running_key_for(edition)

    return if !force && Rails.cache.exist?(lock_key)

    Rails.cache.write(lock_key, true, expires_in: 30.minutes)
    FeatureCatalog.run_all(edition, force: force)
  ensure
    Rails.cache.delete(lock_key)
  end
end
