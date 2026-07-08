# frozen_string_literal: true

# Loads prebuilt verse and word-stream indexes for every bundled edition at boot so
# Discover scans and Scripture links never pay a full-text parse or SQL verse scan.
class EditionWarmup
  class << self
    def warm_all!(build_if_missing: !Rails.env.production?)
      EditionContext.all_ids.each do |edition_id|
        warm_edition!(edition_id, build_if_missing: build_if_missing)
      end
    end

    def warm_edition!(edition_id, build_if_missing: !Rails.env.production?)
      ensure_verse_index!(edition_id, build_if_missing: build_if_missing)
      ensure_word_stream!(edition_id, build_if_missing: build_if_missing)
      ensure_lexicon!(edition_id, build_if_missing: build_if_missing)
      ensure_canon_ordinals!(edition_id, build_if_missing: build_if_missing)

      edition = EditionContext.new(edition_id)
      edition.warm!
    end

    private

    def ensure_lexicon!(edition_id, build_if_missing:)
      path = Inamen::LexiconPublisher.prebuilt_path(edition_id)
      return if File.file?(path)
      return unless build_if_missing

      Rails.logger.info("[EditionWarmup] Building lexicon for #{edition_id}")
      Inamen::LexiconPublisher.build_prebuilt!(edition_id)
    end

    def ensure_canon_ordinals!(edition_id, build_if_missing:)
      path = Inamen::CanonOrdinalsPublisher.prebuilt_path(edition_id)
      return if File.file?(path)
      return unless build_if_missing

      Rails.logger.info("[EditionWarmup] Building canon ordinals for #{edition_id}")
      Inamen::CanonOrdinalsPublisher.build_prebuilt!(edition_id)
    end

    def ensure_verse_index!(edition_id, build_if_missing:)
      path = Inamen::VerseIndexPublisher.prebuilt_path(edition_id)
      return if File.file?(path)
      return unless build_if_missing

      Rails.logger.info("[EditionWarmup] Building verse index for #{edition_id}")
      Inamen::VerseIndexPublisher.build_prebuilt!(edition_id)
    end

    def ensure_word_stream!(edition_id, build_if_missing:)
      path = Inamen::WordStreamPublisher.prebuilt_path(edition_id)
      return if File.file?(path)
      return unless build_if_missing

      Rails.logger.info("[EditionWarmup] Building word stream for #{edition_id}")
      Inamen::WordStreamPublisher.build_prebuilt!(edition_id)
    end
  end
end
