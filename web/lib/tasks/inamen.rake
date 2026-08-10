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
      FileStatsStore.populate_all!(editions, force: force).each do |snapshot|
        puts "file_stats_db:#{snapshot.edition_short_name}"
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

  namespace :file_stats do
    desc "Populate DB-backed file stats for all editions (set FORCE=1 to rebuild, FULL=1 to prefill every character breakdown)"
    task populate: :environment do
      force = ENV["FORCE"] == "1"
      full = ENV["FULL"] == "1"
      editions =
        if ENV["EDITION"].present?
          [Edition.find_by!(short_name: ENV["EDITION"])]
        else
          Edition.ordered
        end

      editions.each do |edition|
        next if !force && FileStatsStore.current_snapshot_for(edition)

        print "#{edition.short_name}..."
        snapshot = FileStatsStore.populate!(edition, full: full)
        puts "#{snapshot.edition_short_name}: #{snapshot.total} tokens, #{snapshot.character_count} characters"
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

  desc "Remove an edition and generated artifacts, preserving the source file: bin/rails editions:remove EDITION=..."
  task remove: :environment do
    edition_id = ENV["EDITION"].presence || ENV["ID"].presence || ENV["NAME"].presence
    result = EditionRemover.remove!(edition_id: edition_id)

    puts "Removed edition #{result.edition_id}"
    puts "Preserved source: #{result.source_path}"
    puts "Deleted feature edition rows: #{result.deleted_feature_editions}"
    puts "Deleted generated artifacts: #{result.deleted_artifacts.length}"
    result.deleted_artifacts.each { |path| puts path }
    if result.deleted_artifact_dirs.any?
      puts "Deleted generated artifact directories: #{result.deleted_artifact_dirs.length}"
      result.deleted_artifact_dirs.each { |path| puts path }
    end

    if result.deleted_generated_texts.any?
      puts "Deleted generated text copies: #{result.deleted_generated_texts.length}"
      result.deleted_generated_texts.each { |path| puts path }
    end
  rescue ArgumentError => e
    warn "Remove failed: #{e.message}"
    exit 1
  end
end
