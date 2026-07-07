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

  def verse_text(book:, chapter:, verse:)
    Inamen::VerseIndex.verse_text_from_index(chapter_index, book: book, chapter: chapter, verse: verse)
  end

  def warm!
    chapter_index
    self
  end

  def checksum_prefix
    @checksum_prefix ||= Inamen::CorpusPublisher.checksum_prefix(path)
  end

  def verse_index_prebuilt_path
    Inamen::VerseIndexPublisher.prebuilt_path(edition_id, text_path: path)
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
    @lexicons[key] ||= Inamen::Lexicon.for(db, search_selection: search_selection)
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

  def ensure_corpus_file!
    sqlite_path = corpus_db_path
    return if sqlite_path.file?

    FileUtils.mkdir_p(sqlite_path.dirname)
    Inamen::CorpusStore.build!(lines, path: sqlite_path.to_s)
  end
end
