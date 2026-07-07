# frozen_string_literal: true

# Loads prebuilt verse indices for every bundled edition at boot so Scripture and
# Discover verse links never pay a full-text parse on the request path.
class EditionWarmup
  class << self
    def warm_all!(build_if_missing: !Rails.env.production?)
      EditionContext.all_ids.each do |edition_id|
        warm_edition!(edition_id, build_if_missing: build_if_missing)
      end
    end

    def warm_edition!(edition_id, build_if_missing: !Rails.env.production?)
      path = Inamen::VerseIndexPublisher.prebuilt_path(edition_id)
      unless File.file?(path)
        if build_if_missing
          Rails.logger.info("[EditionWarmup] Building verse index for #{edition_id}")
          Inamen::VerseIndexPublisher.build_prebuilt!(edition_id)
        else
          Rails.logger.warn("[EditionWarmup] Missing prebuilt verse index for #{edition_id} at #{path}")
        end
      end

      EditionContext.new(edition_id).warm!
    end
  end
end
