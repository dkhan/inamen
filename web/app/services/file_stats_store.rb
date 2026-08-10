# frozen_string_literal: true

require "csv"

class FileStatsStore
  BATCH_SIZE = 5_000

  DbExplorer = Struct.new(:edition_id, :snapshot_id, keyword_init: true) do
    def root
      @root ||= FileStatsStore.node_for(snapshot_id, parent_id: nil)
    end

    def children_of(node_id)
      FileStatsStore.children_for(snapshot_id, node_id)
    end

    def has_children?(node_id)
      FileStatsStore.children_exist?(snapshot_id, node_id)
    end

    def categories_for(node_id)
      FileStatsStore.categories_for(snapshot_id, node_id)
    end

    def characters_for(node_id)
      FileStatsStore.characters_for(snapshot_id, node_id)
    end

    def character_breakdown_for(node_id)
      {
        categories: categories_for(node_id),
        characters: characters_for(node_id)
      }
    end
  end

  class << self
    def load(edition)
      snapshot = current_snapshot_for(edition)
      return nil unless snapshot

      explorer = DbExplorer.new(
        edition_id: edition.edition_id,
        snapshot_id: snapshot.id
      )

      Inamen::FileStatsReport::Result.new(
        rows: snapshot.rows.map { |row| Inamen::FileStatsReport::Row.new(key: row.fetch("key").to_sym, label: row.fetch("label"), count: row.fetch("count").to_i) },
        total: snapshot.total,
        character_count: snapshot.character_count,
        seven_power: snapshot.seven_power,
        explorer: explorer
      )
    end

    def populate!(edition, result: nil, full: false)
      result ||= build_result_for(edition)
      snapshot = nil

      FileStatSnapshot.transaction do
        FileStatSnapshot.where(edition: edition).destroy_all
        snapshot = FileStatSnapshot.create!(
          edition: edition,
          edition_short_name: edition.short_name,
          source_checksum: edition.source_checksum,
          publisher_revision: Inamen::FileStatsPublisher::FILE_STATS_REVISION,
          explorer_cache_version: Inamen::FileStatsExplorer::CACHE_VERSION,
          total: result.total,
          character_count: result.character_count,
          seven_power: result.seven_power,
          rows: result.rows.map { |row| { key: row.key.to_s, label: row.label, count: row.count } }
        )

        insert_nodes!(snapshot, result.explorer.nodes)
        if full
          insert_node_breakdowns!(snapshot, edition.edition_id)
        else
          insert_root_breakdowns!(snapshot, result.explorer)
        end
      end

      snapshot
    end

    def populate_all!(editions = Edition.ordered.to_a, force: false, full: false)
      editions.filter_map do |edition|
        next if !force && current_snapshot_for(edition)

        populate!(edition, full: full)
      end.compact
    end

    def categories_for(snapshot_id, node_id)
      hydrate_node_breakdown!(snapshot_id, node_id)
      category_records(snapshot_id, node_id).map do |row|
        Inamen::FileStatsExplorer::Category.new(
          node_id: row.node_id,
          category: row.category,
          subcategory: row.subcategory,
          count: row.count
        )
      end
    end

    def characters_for(snapshot_id, node_id)
      hydrate_node_breakdown!(snapshot_id, node_id)
      character_records(snapshot_id, node_id).map do |row|
        Inamen::FileStatsExplorer::Character.new(
          node_id: row.node_id,
          category: row.category,
          char: row.char,
          codepoint: row.codepoint,
          name: row.name,
          count: row.count
        )
      end
    end

    def current_snapshot_for(edition)
      FileStatSnapshot.find_by(
        edition: edition,
        source_checksum: edition.source_checksum,
        publisher_revision: Inamen::FileStatsPublisher::FILE_STATS_REVISION,
        explorer_cache_version: Inamen::FileStatsExplorer::CACHE_VERSION
      )
    end

    def node_for(snapshot_id, parent_id:)
      record = FileStatNode.where(file_stat_snapshot_id: snapshot_id, parent_id: parent_id).order(:id).first
      record && node_from_record(record)
    end

    def children_for(snapshot_id, node_id)
      FileStatNode.where(file_stat_snapshot_id: snapshot_id, parent_id: node_id.to_s).order(:id).map do |record|
        node_from_record(record)
      end
    end

    def children_exist?(snapshot_id, node_id)
      FileStatNode.where(file_stat_snapshot_id: snapshot_id, parent_id: node_id.to_s).exists?
    end

    private

    def build_result_for(edition)
      checksum = Inamen::CorpusPublisher.checksum_prefix(edition.path)
      if Inamen::FileStatsExplorer.cache_current?(edition.edition_id, checksum)
        result = Inamen::FileStatsReport.build(edition.lines, text_path: edition.path, source_lines: edition.source_lines)
        result.explorer = Inamen::FileStatsExplorer.load_cache(edition.edition_id)
        return result
      end

      Inamen::FileStatsPublisher.load_for(edition.edition_id, text_path: edition.path) || begin
        path = Inamen::FileStatsPublisher.build_prebuilt!(
          edition.edition_id,
          text_path: edition.path,
          lines: edition.lines,
          source_lines: edition.source_lines,
          force: false
        )
        Inamen::FileStatsPublisher.load_prebuilt!(path)
      end
    end

    def insert_root_breakdowns!(snapshot, explorer)
      insert_categories!(snapshot, explorer.categories_for(explorer.root.node_id))
      insert_characters!(snapshot, explorer.characters_for(explorer.root.node_id))
    end

    def insert_nodes!(snapshot, nodes)
      now = Time.current
      nodes.each_slice(BATCH_SIZE) do |batch|
        FileStatNode.insert_all!(
          batch.map do |node|
            {
              file_stat_snapshot_id: snapshot.id,
              node_id: node.node_id,
              parent_id: node.parent_id,
              level: node.level,
              label: node.label,
              testament: node.testament,
              book: node.book,
              chapter: node.chapter,
              verse: node.verse,
              word_count: node.word_count,
              number_count: node.number_count,
              division_count: node.division_count,
              character_count: node.character_count,
              letter_count: node.letter_count,
              digit_count: node.digit_count,
              other_count: node.other_count,
              created_at: now,
              updated_at: now
            }
          end
        )
      end
    end

    def insert_node_breakdowns!(snapshot, edition_id)
      path = File.join(Inamen::FileStatsExplorer.cache_dir(edition_id), "node_characters.csv")
      return unless File.file?(path)

      category_counts_by_node = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      character_rows = []
      now = Time.current

      CSV.foreach(path, headers: true) do |row|
        node_id = row.fetch("node_id")
        point = row.fetch("codepoint")
        char = char_from_codepoint(point)
        count = row.fetch("count").to_i

        Inamen::FileStatsExplorer.send(:categories_for_char, char).each do |category, subcategory|
          category_counts_by_node[node_id][[category, subcategory]] += count
        end

        character_rows << {
          file_stat_snapshot_id: snapshot.id,
          node_id: node_id,
          category: row.fetch("category"),
          char: char,
          codepoint: point,
          name: row.fetch("name"),
          count: count,
          created_at: now,
          updated_at: now
        }
        flush_insert!(FileStatCharacter, character_rows)
      end
      flush_insert!(FileStatCharacter, character_rows, force: true)

      category_rows = []
      category_counts_by_node.each do |node_id, counts|
        counts.sort.each do |(category, subcategory), count|
          category_rows << {
            file_stat_snapshot_id: snapshot.id,
            node_id: node_id,
            category: category,
            subcategory: subcategory,
            count: count,
            created_at: now,
            updated_at: now
          }
          flush_insert!(FileStatCategory, category_rows)
        end
      end
      flush_insert!(FileStatCategory, category_rows, force: true)
    end

    def hydrate_node_breakdown!(snapshot_id, node_id)
      return if category_records(snapshot_id, node_id).exists? && character_records(snapshot_id, node_id).exists?

      snapshot = FileStatSnapshot.find(snapshot_id)
      return if node_id.to_s == snapshot.edition_short_name

      breakdown = Inamen::FileStatsExplorer.character_breakdown_for(snapshot.edition_short_name, node_id.to_s)
      FileStatCategory.where(file_stat_snapshot_id: snapshot.id, node_id: node_id.to_s).delete_all
      FileStatCharacter.where(file_stat_snapshot_id: snapshot.id, node_id: node_id.to_s).delete_all
      insert_categories!(snapshot, breakdown.fetch(:categories))
      insert_characters!(snapshot, breakdown.fetch(:characters))
    rescue Errno::ENOENT
      nil
    end

    def category_records(snapshot_id, node_id)
      FileStatCategory.where(file_stat_snapshot_id: snapshot_id, node_id: node_id.to_s).order(:category, :subcategory)
    end

    def character_records(snapshot_id, node_id)
      FileStatCharacter.where(file_stat_snapshot_id: snapshot_id, node_id: node_id.to_s).order(:codepoint)
    end

    def insert_categories!(snapshot, categories)
      now = Time.current
      FileStatCategory.insert_all!(
        categories.map do |row|
          {
            file_stat_snapshot_id: snapshot.id,
            node_id: row.node_id,
            category: row.category,
            subcategory: row.subcategory,
            count: row.count,
            created_at: now,
            updated_at: now
          }
        end
      ) if categories.any?
    end

    def insert_characters!(snapshot, characters)
      now = Time.current
      FileStatCharacter.insert_all!(
        characters.map do |row|
          {
            file_stat_snapshot_id: snapshot.id,
            node_id: row.node_id,
            category: row.category,
            char: row.char,
            codepoint: row.codepoint,
            name: row.name,
            count: row.count,
            created_at: now,
            updated_at: now
          }
        end
      ) if characters.any?
    end

    def flush_insert!(model, rows, force: false)
      return if rows.empty?
      return if !force && rows.length < BATCH_SIZE

      model.insert_all!(rows)
      rows.clear
    end

    def char_from_codepoint(value)
      value.to_s.delete_prefix("U+").to_i(16).chr(Encoding::UTF_8)
    end

    def node_from_record(record)
      Inamen::FileStatsExplorer::Node.new(
        node_id: record.node_id,
        parent_id: record.parent_id,
        level: record.level,
        label: record.label,
        testament: record.testament,
        book: record.book,
        chapter: record.chapter,
        verse: record.verse,
        word_count: record.word_count,
        number_count: record.number_count,
        division_count: record.division_count,
        character_count: record.character_count,
        letter_count: record.letter_count,
        digit_count: record.digit_count,
        other_count: record.other_count
      )
    end
  end
end
