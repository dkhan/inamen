# frozen_string_literal: true

Rails.application.config.after_initialize do
  next if Rails.env.test?

  Thread.new do
    Rails.application.executor.wrap do
      Rails.logger.info("[EditionWarmup] Checking prebuilt edition artifacts in background")
      EditionWarmup.warm_all!(build_if_missing: false, load_indexes: false)
      Rails.logger.info("[EditionWarmup] Ready")
    end
  rescue StandardError => e
    Rails.logger.error("[EditionWarmup] #{e.class}: #{e.message}")
  end
end
