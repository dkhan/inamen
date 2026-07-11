# frozen_string_literal: true

require "fileutils"

# Loads a bundled KJV edition and provides cached corpus DB access for feature runs.
class EditionContext
  attr_reader :edition_id, :path

  def initialize(edition_id)
    @edition_id = edition_id.to_s
    @path = Inamen::KjvEditions::EDITIONS.fetch(@edition_id) do
      raise ArgumentError, "Unknown edition: #{@edition_id.inspect}"
    end
  end

  def self.all_ids
    Inamen::KjvEditions::EDITIONS.keys
  end

  def filename
    File.basename(path)
  end

  def lines
    @lines ||= Inamen::KjvEditions.read_lines(path)
  end

  def cache_key
    "#{edition_id}:#{checksum_prefix}"
  end

  def chapter_index
    @chapter_index ||= Inamen::VerseIndex.chapter_index_for(
      cache_key,
      lines: lines,
      prebuilt_path: verse_index_prebuilt_path
    )
  end

  def verse_map
    @verse_map ||= Inamen::VerseIndex.flatten_chapter_index(chapter_index)
  end

  def chapter_verses(book:, chapter:)
    Inamen::VerseIndex.chapter_verses_from_index(chapter_index, book: book, chapter: chapter)
  end

  def dictionary_words
    stream = word_stream_index
    return [] unless stream

    stream.postings_raw.keys.sort
  end

  def phrase_completer(case_sensitive: false)
    @phrase_completers ||= {}
    key = case_sensitive ? "cs" : "ci"
    stream = word_stream_index
    return nil unless stream

    @phrase_completers[key] ||= Inamen::PhraseCompleter.from_word_stream(stream, case_sensitive: case_sensitive)
  end

  def verse_text(book:, chapter:, verse:)
    Inamen::VerseIndex.verse_text_from_index(chapter_index, book: book, chapter: chapter, verse: verse)
  end

  def file_stats
    @file_stats ||= Inamen::FileStatsPublisher.resolve(edition_id, lines: lines, text_path: path)
  end

  def file_stats_prebuilt_path
    Inamen::FileStatsPublisher.prebuilt_path(edition_id, text_path: path)
  end

  def warm!
    chapter_index
    word_stream_index
    install_canon_ordinals! if corpus_ready?
    lexicon if corpus_ready?
    self
  end

  def word_stream_index
    @word_stream_index = load_word_stream_index unless defined?(@word_stream_index)
    @word_stream_index
  end

  def word_stream_ready?
    word_stream_prebuilt_path.file?
  end

  def checksum_prefix
    @checksum_prefix ||= Inamen::CorpusPublisher.checksum_prefix(path)
  end

  def verse_index_prebuilt_path
    Inamen::VerseIndexPublisher.prebuilt_path(edition_id, text_path: path)
  end

  def word_stream_prebuilt_path
    Pathname(Inamen::WordStreamPublisher.prebuilt_path(edition_id, text_path: path))
  end

  def lexicon_prebuilt_path
    Pathname(Inamen::LexiconPublisher.prebuilt_path(edition_id))
  end

  def canon_ordinals_prebuilt_path
    Pathname(Inamen::CanonOrdinalsPublisher.prebuilt_path(edition_id))
  end

  def expected_count(feature_id)
    Inamen::KjvEditions.expected_feature_count(edition_id, feature_id)
  end

  def db
    @db ||= begin
      ensure_corpus_file!
      Inamen::CorpusStore.open(corpus_db_path.to_s)
    end
  end

  def lexicon(search_selection = Inamen::SearchSelection.default)
    @lexicons ||= {}
    key = search_selection.cache_key
    return @lexicons[key] if @lexicons.key?(key)

    if search_selection == Inamen::SearchSelection.default && lexicon_prebuilt_path.file?
      dump = Inamen::LexiconPublisher.load_prebuilt!(lexicon_prebuilt_path.to_s)
      @lexicons[key] = Inamen::Lexicon.from_dump(dump, search_selection: search_selection)
    else
      @lexicons[key] = Inamen::Lexicon.for(db, search_selection: search_selection)
    end
  end

  def corpus_db_path
    prebuilt = Pathname(Inamen::CorpusPublisher.prebuilt_path(edition_id, text_path: path))
    return prebuilt if prebuilt.file?

    @runtime_corpus_path ||= Rails.root.join(
      "tmp/corpora",
      Inamen::CorpusPublisher.corpus_filename(edition_id, checksum_prefix)
    )
  end

  def corpus_ready?
    corpus_db_path.file?
  end

  private

  def load_word_stream_index
    path = word_stream_prebuilt_path
    return nil unless path.file?

    Inamen::WordStreamIndex.for_edition(cache_key, prebuilt_path: path.to_s)
  rescue StandardError => e
    Rails.logger.warn("[EditionContext] word stream load failed for #{edition_id}: #{e.message}")
    nil
  end

  def ensure_corpus_file!
    sqlite_path = corpus_db_path
    return if sqlite_path.file?

    FileUtils.mkdir_p(sqlite_path.dirname)
    Inamen::CorpusStore.build!(lines, path: sqlite_path.to_s)
  end

  def install_canon_ordinals!
    path = canon_ordinals_prebuilt_path
    return unless path.file?

    data = Inamen::CanonOrdinalsPublisher.load_prebuilt!(path.to_s)
    Inamen::CanonIndex.install_prebuilt!(
      db,
      ordinals: data.fetch(:ordinals),
      nt_first: data.fetch(:nt_first)
    )
  end
end
