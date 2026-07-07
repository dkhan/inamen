# frozen_string_literal: true

Rails.application.config.after_initialize do
  next if Rails.env.test?

  EditionWarmup.warm_all!
end
