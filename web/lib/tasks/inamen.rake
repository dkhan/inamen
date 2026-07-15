# frozen_string_literal: true

namespace :inamen do
  namespace :corpora do
    desc "Build prebuilt SQLite corpora for all editions (set FORCE=1 to rebuild)"
    task prebuild: :environment do
      force = ENV["FORCE"] == "1"
      editions = Edition.ordered.to_a
      Inamen::CorpusPublisher.build_all_prebuilt!(editions, force: force).each do |built_path|
        puts built_path
      end
      Inamen::VerseIndexPublisher.build_all_prebuilt!(editions, force: force).each do |built_path|
        puts built_path
      end
      Inamen::FileStatsPublisher.build_all_prebuilt!(editions, force: force).each do |built_path|
        puts built_path
      end
      Inamen::WordStreamPublisher.build_all_prebuilt!(editions, force: force).each do |built_path|
        puts built_path
      end
      Inamen::LexiconPublisher.build_all_prebuilt!(editions, force: force).each do |built_path|
        puts built_path
      end
      Inamen::CanonOrdinalsPublisher.build_all_prebuilt!(editions, force: force).each do |built_path|
        puts built_path
      end
    end
  end

  namespace :verse_indices do
    desc "Build prebuilt verse indices for all editions (set FORCE=1 to rebuild)"
    task prebuild: :environment do
      force = ENV["FORCE"] == "1"
      Inamen::VerseIndexPublisher.build_all_prebuilt!(Edition.ordered.to_a, force: force).each do |built_path|
        puts built_path
      end
    end
  end
end

namespace :editions do
  desc "Import a local plain-text edition: bin/rails editions:import FILE=... TYPE=bible NAME=..."
  task import: :environment do
    file = ENV.fetch("FILE") { raise "FILE is required" }
    type = ENV.fetch("TYPE", "bible")
    name = ENV["NAME"]

    result = EditionImporter.import!(file: file, type: type, name: name)
    puts "Imported #{result.edition.short_name} (#{result.edition.name})"
    result.paths.each_value { |path| puts path }
  rescue ArgumentError => e
    warn "Import failed: #{e.message}"
    exit 1
  end
end
