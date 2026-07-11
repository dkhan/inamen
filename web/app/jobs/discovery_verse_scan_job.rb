# frozen_string_literal: true

class DiscoveryVerseScanJob < ApplicationJob
  queue_as :default

  def perform(edition_id, scan_params, force: false)
    edition = EditionContext.new(edition_id)
    params = DiscoveryScan.normalize(scan_params)
    lock_key = DiscoveryScan.verses_running_key_for(edition, params)

    return if !force && (Rails.cache.exist?(lock_key) || DiscoveryScan.verses_cached?(edition, params))

    Rails.cache.write(lock_key, true, expires_in: 30.minutes)
    edition.warm!
    DiscoveryScan.run_verses(edition, params, force: force)
  ensure
    Rails.cache.delete(lock_key)
  end
end
