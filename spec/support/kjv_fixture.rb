# frozen_string_literal: true

require "digest"
require "tmpdir"
require "inamen/corpus_store"

module Inamen
  # Shared KJV lines and corpus DB for integration specs (built once per process).
  module KjvFixture
    KJV_PATH = File.expand_path("../../data/KJV.txt", __dir__)

    module_function

    def lines
      @lines ||= File.readlines(KJV_PATH, chomp: true)
    end

    # Bump when tokenization or indexing rules change (invalidates cached SQLite).
    INDEXER_REVISION = "4"

    def db_path
      @db_path ||= begin
        digest = Digest::SHA256.file(KJV_PATH).hexdigest[0, 16]
        File.join(Dir.tmpdir, "inamen-kjv-#{digest}-#{INDEXER_REVISION}.sqlite")
      end
    end

    def db
      @db ||= begin
        CorpusStore.build!(lines, path: db_path) unless File.file?(db_path)
        CorpusStore.open(db_path)
      end
    end
  end
end
