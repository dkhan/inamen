# frozen_string_literal: true

Rails.application.config.after_initialize do
  next if Rails.env.test?

  Thread.new do
    Rails.logger.info("[EditionWarmup] Loading prebuilt indexes in background")
    EditionWarmup.warm_all!
    Rails.logger.info("[EditionWarmup] Ready")
  rescue StandardError => e
    Rails.logger.error("[EditionWarmup] #{e.class}: #{e.message}")
  end
end
