# frozen_string_literal: true

require "sqlite3"
require "fileutils"
require "securerandom"

require_relative "corpus_indexer"

module Inamen
  # SQLite corpus: one row per token occurrence with book/chapter/verse location.
  module CorpusStore
    DEFAULT_PATH = File.expand_path("../../data/kjv_corpus.sqlite", __dir__)
    SCHEMA_VERSION = 2
    # Bump when indexing or tokenization rules change (invalidates cached corpora).
    INDEXER_REVISION = "14"

    BUCKET_VERSE_TEXT = "verse_text"
    BUCKET_PSALM_HEADING = "psalm_heading"
    BUCKET_COLOPHON = "colophon"
    SCAN_BUCKETS = [BUCKET_VERSE_TEXT, BUCKET_PSALM_HEADING, BUCKET_COLOPHON].freeze

    OT_BOOKS = BookStatsReport::CANON.first(39).map(&:first).freeze
    NT_BOOKS = BookStatsReport::CANON.drop(39).map(&:first).freeze
    TESTAMENT_BY_BOOK = BibleBooks::ALL.to_h { |book| [book, BibleBooks.testament_for(book)] }.freeze

    INSERT_BATCH_SIZE = 500
    class << self
      def build!(lines, path: DEFAULT_PATH)
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir)
        tmp_path = File.join(dir, ".#{File.basename(path)}.#{Process.pid}.#{SecureRandom.hex(6)}.tmp")

        db = open_db(tmp_path)
        create_schema!(db)
        insert_tokens!(db, lines)
        populate_token_counts!(db)
        record_build_metadata!(db, lines)
        db.close
        replace_database!(tmp_path, path)
        path
      ensure
        db&.close
        cleanup_database_files!(tmp_path) if tmp_path
      end

      def open(path = DEFAULT_PATH)
        raise ArgumentError, "Corpus not found at #{path.inspect} (run: bin/inamen index)" unless File.file?(path)

        db = open_db(path)
        create_schema!(db) unless schema_present?(db)
        ensure_token_counts!(db)
        db
      end

      def token_count(db, buckets: SCAN_BUCKETS)
        list = Array(buckets)
        placeholders = (["?"] * list.length).join(", ")
        db.get_first_value(
          "SELECT COUNT(*) FROM tokens WHERE bucket IN (#{placeholders})",
          list
        ).to_i
      end

      def bucket_counts(db)
        SCAN_BUCKETS.to_h do |bucket|
          [bucket, token_count(db, buckets: [bucket])]
        end
      end

      def normalize_token(token)
        fold_ligatures(normalize_apostrophes(token.to_s.downcase))
      end

      def fold_ligatures(str)
        str.to_s.gsub("æ", "ae").gsub("œ", "oe")
      end

      def normalize_apostrophes(str)
        str.to_s.tr("'", "\u{2019}")
      end

      def apostrophe_equivalent_strings(str)
        text = str.to_s
        variants = [normalize_apostrophes(text)]
        variants << text.tr("\u{2019}", "'") if text.include?("\u{2019}") || text.include?("'")
        variants.uniq
      end

      def testament_for(book)
        TESTAMENT_BY_BOOK[book] or raise ArgumentError, "Unknown book: #{book.inspect}"
      end

      def resolve_buckets(bucket)
        return SCAN_BUCKETS if bucket.nil? || bucket == :default || bucket == "default" || bucket == "scannable"

        Array(bucket)
      end

      def token_counts_available?(db)
        db.get_first_value("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'token_counts'").to_i == 1 &&
          db.get_first_value("SELECT COUNT(*) FROM token_counts").to_i.positive?
      end

      private

      def open_db(path)
        SQLite3::Database.new(path).tap do |db|
          db.busy_timeout = 5_000
          db.execute("PRAGMA journal_mode = WAL")
          db.execute("PRAGMA synchronous = NORMAL")
        end
      end

      def replace_database!(tmp_path, path)
        cleanup_database_files!(path)
        FileUtils.mv(tmp_path, path)
        cleanup_database_files!(tmp_path)
      end

      def cleanup_database_files!(path)
        [path, "#{path}-wal", "#{path}-shm"].each do |candidate|
          File.delete(candidate) if candidate && File.exist?(candidate)
        end
      end

      def schema_present?(db)
        db.get_first_value("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'tokens'")
      end

      def create_schema!(db)
        db.execute_batch(<<~SQL)
          CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          );

          CREATE TABLE IF NOT EXISTS tokens (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book TEXT NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            word_index INTEGER NOT NULL,
            token_raw TEXT NOT NULL,
            token_norm TEXT NOT NULL,
            testament TEXT NOT NULL CHECK (testament IN ('OT', 'NT', 'AP')),
            bucket TEXT NOT NULL,
            lineno INTEGER NOT NULL DEFAULT 0,
            UNIQUE (book, chapter, verse, bucket, lineno, word_index)
          );

          CREATE INDEX IF NOT EXISTS idx_tokens_norm_bucket ON tokens (token_norm, bucket);
          CREATE INDEX IF NOT EXISTS idx_tokens_testament ON tokens (testament, bucket);
          CREATE INDEX IF NOT EXISTS idx_tokens_book ON tokens (book, bucket);
          CREATE INDEX IF NOT EXISTS idx_tokens_ref_bucket ON tokens (book, chapter, verse, bucket, word_index);

          CREATE TABLE IF NOT EXISTS token_counts (
            token_norm TEXT NOT NULL,
            token_raw TEXT NOT NULL,
            bucket TEXT NOT NULL,
            testament TEXT NOT NULL CHECK (testament IN ('OT', 'NT', 'AP')),
            book TEXT NOT NULL,
            count INTEGER NOT NULL,
            PRIMARY KEY (token_norm, token_raw, bucket, testament, book)
          );

          CREATE INDEX IF NOT EXISTS idx_token_counts_norm ON token_counts (token_norm);
          CREATE INDEX IF NOT EXISTS idx_token_counts_raw ON token_counts (token_raw);
          CREATE INDEX IF NOT EXISTS idx_token_counts_bucket_book ON token_counts (bucket, book);
        SQL
      end

      def insert_tokens!(db, lines)
        db.execute("PRAGMA journal_mode = OFF")
        db.execute("PRAGMA synchronous = OFF")
        db.execute("PRAGMA temp_store = MEMORY")
        db.execute("PRAGMA cache_size = -64000")

        columns = %i[book chapter verse word_index token_raw token_norm testament bucket lineno]
        batch = []

        db.transaction do
          CorpusIndexer.each_token_record(lines) do |rec|
            batch << [
              rec[:book], rec[:chapter], rec[:verse], rec[:word_index],
              rec[:token_raw], normalize_token(rec[:token_raw]), rec[:testament],
              rec[:bucket], rec[:lineno]
            ]
            next if batch.length < INSERT_BATCH_SIZE

            flush_insert_batch!(db, columns, batch)
            batch.clear
          end
          flush_insert_batch!(db, columns, batch) unless batch.empty?
        end
      end

      def flush_insert_batch!(db, columns, batch)
        return if batch.empty?

        row = "(#{(['?'] * columns.length).join(', ')})"
        placeholders = ([row] * batch.length).join(", ")
        sql = "INSERT INTO tokens (#{columns.join(', ')}) VALUES #{placeholders}"
        db.execute(sql, batch.flatten)
      end

      def populate_token_counts!(db)
        db.execute("DELETE FROM token_counts")
        db.execute(<<~SQL)
          INSERT INTO token_counts (token_norm, token_raw, bucket, testament, book, count)
          SELECT token_norm, token_raw, bucket, testament, book, COUNT(*) AS count
          FROM tokens
          GROUP BY token_norm, token_raw, bucket, testament, book
        SQL
      end

      def ensure_token_counts!(db)
        return unless schema_present?(db)

        create_schema!(db)
        token_rows = db.get_first_value("SELECT COUNT(*) FROM tokens").to_i
        return if token_rows.zero?

        count_rows = db.get_first_value("SELECT COUNT(*) FROM token_counts").to_i
        populate_token_counts!(db) if count_rows.zero?
      end

      def record_build_metadata!(db, lines)
        db.execute("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", ["schema_version", SCHEMA_VERSION.to_s])
        bucket_counts(db).each do |bucket, count|
          db.execute(
            "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)",
            ["token_rows_#{bucket}", count.to_s]
          )
        end
        db.execute(
          "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)",
          ["token_rows_scannable", token_count(db).to_s]
        )
        db.execute(
          "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)",
          ["token_count_rows", db.get_first_value("SELECT COUNT(*) FROM token_counts").to_s]
        )
        db.execute(
          "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)",
          ["source_lines", lines.length.to_s]
        )
      end
    end
  end
end
