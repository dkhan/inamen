# frozen_string_literal: true

# Ensures prebuilt artifacts exist for imported editions. Callers can choose
# whether to also load indexes into process memory.
class EditionWarmup
  class << self
    def warm_all!(build_if_missing: !Rails.env.production?, load_indexes: true)
      EditionContext.all_ids.each do |edition_id|
        warm_edition!(edition_id, build_if_missing: build_if_missing, load_indexes: load_indexes)
      end
    end

    def warm_edition!(edition_id, build_if_missing: !Rails.env.production?, load_indexes: true)
      edition = EditionContext.new(edition_id)
      ensure_corpus!(edition, build_if_missing: build_if_missing)
      ensure_verse_index!(edition, build_if_missing: build_if_missing)
      ensure_word_stream!(edition, build_if_missing: build_if_missing)
      ensure_lexicon!(edition, build_if_missing: build_if_missing)
      ensure_canon_ordinals!(edition, build_if_missing: build_if_missing)
      edition.warm! if load_indexes
    end

    private

    def ensure_corpus!(edition, build_if_missing:)
      path = Inamen::CorpusPublisher.prebuilt_path(edition.edition_id, text_path: edition.corpus_text_path)
      return if File.file?(path)
      return unless build_if_missing

      Rails.logger.info("[EditionWarmup] Building corpus for #{edition.edition_id}")
      Inamen::CorpusPublisher.build_prebuilt!(edition.edition_id, text_path: edition.corpus_text_path, lines: edition.lines)
    end

    def ensure_lexicon!(edition, build_if_missing:)
      path = Inamen::LexiconPublisher.prebuilt_path(edition.edition_id, text_path: edition.corpus_text_path)
      return if File.file?(path)
      return unless build_if_missing

      Rails.logger.info("[EditionWarmup] Building lexicon for #{edition.edition_id}")
      Inamen::LexiconPublisher.build_prebuilt!(edition.edition_id, text_path: edition.corpus_text_path)
    end

    def ensure_canon_ordinals!(edition, build_if_missing:)
      path = Inamen::CanonOrdinalsPublisher.prebuilt_path(edition.edition_id, text_path: edition.corpus_text_path)
      return if File.file?(path)
      return unless build_if_missing

      Rails.logger.info("[EditionWarmup] Building canon ordinals for #{edition.edition_id}")
      Inamen::CanonOrdinalsPublisher.build_prebuilt!(edition.edition_id, text_path: edition.corpus_text_path)
    end

    def ensure_verse_index!(edition, build_if_missing:)
      path = Inamen::VerseIndexPublisher.prebuilt_path(edition.edition_id, text_path: edition.corpus_text_path)
      return if File.file?(path)
      return unless build_if_missing

      Rails.logger.info("[EditionWarmup] Building verse index for #{edition.edition_id}")
      Inamen::VerseIndexPublisher.build_prebuilt!(edition.edition_id, text_path: edition.corpus_text_path, lines: edition.lines)
    end

    def ensure_word_stream!(edition, build_if_missing:)
      path = Inamen::WordStreamPublisher.prebuilt_path(edition.edition_id, text_path: edition.corpus_text_path)
      return if File.file?(path)
      return unless build_if_missing

      Rails.logger.info("[EditionWarmup] Building word stream for #{edition.edition_id}")
      Inamen::WordStreamPublisher.build_prebuilt!(edition.edition_id, text_path: edition.corpus_text_path)
    end
  end
end
