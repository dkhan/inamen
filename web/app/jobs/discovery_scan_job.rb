# frozen_string_literal: true

class DiscoveryScanJob < ApplicationJob
  queue_as :default

  def perform(edition_id, scan_params, force: false)
    edition = EditionContext.new(edition_id)
    params = DiscoveryScan.normalize(scan_params)
    lock_key = DiscoveryScan.running_key_for(edition, params)

    return if !force && Rails.cache.exist?(lock_key)

    Rails.cache.write(lock_key, true, expires_in: 30.minutes)
    DiscoveryScan.run(edition, params, force: force)
    DiscoveryScan.enqueue_verses!(edition, params, force: force) if params.mode == "word_count"
  ensure
    Rails.cache.delete(lock_key)
  end
end
