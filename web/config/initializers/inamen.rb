# frozen_string_literal: true

data_root = Rails.root.join("..", "data").expand_path

unless data_root.directory?
  raise "Inamen data directory not found at #{data_root}"
end

Rails.application.config.inamen = ActiveSupport::OrderedOptions.new
Rails.application.config.inamen.data_root = data_root
Rails.application.config.inamen.corpora_root = data_root.join("corpora")
Rails.application.config.inamen.verse_indices_root = data_root.join("verse_indices")
Rails.application.config.inamen.word_streams_root = data_root.join("word_streams")
Rails.application.config.inamen.engine_version = Inamen::VERSION
Rails.application.config.inamen.indexer_revision = Inamen::CorpusStore::INDEXER_REVISION
Rails.application.config.discover_server_epoch = SecureRandom.hex(16)
