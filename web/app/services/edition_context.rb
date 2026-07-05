# frozen_string_literal: true

require "digest"
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

  def checksum_prefix
    @checksum_prefix ||= Digest::SHA256.file(path).hexdigest[0, 16]
  end

  def expected_count(feature_id)
    Inamen::KjvEditions.expected_feature_count(edition_id, feature_id)
  end

  def db
    @db ||= begin
      sqlite_path = corpus_db_path
      FileUtils.mkdir_p(sqlite_path.dirname)
      Inamen::CorpusStore.build!(lines, path: sqlite_path.to_s) unless sqlite_path.file?
      Inamen::CorpusStore.open(sqlite_path.to_s)
    end
  end

  def corpus_db_path
    Rails.root.join(
      "tmp/corpora",
      "#{edition_id}-#{checksum_prefix}-#{Inamen::CorpusStore::INDEXER_REVISION}.sqlite"
    )
  end
end
