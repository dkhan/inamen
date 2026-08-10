# frozen_string_literal: true

require "test_helper"

class FileStatsStoreTest < ActiveSupport::TestCase
  test "populates and loads current DB file stats snapshot" do
    edition = create_store_edition("store_current")
    root = Inamen::FileStatsExplorer::Node.new(
      node_id: "store_current:edition",
      parent_id: nil,
      level: "edition",
      label: "store_current",
      word_count: 2,
      number_count: 1,
      division_count: 1,
      character_count: 12,
      letter_count: 8,
      digit_count: 1,
      other_count: 3
    )
    explorer = Inamen::FileStatsExplorer::Result.new(
      edition_id: edition.edition_id,
      nodes: [root],
      categories: [],
      characters: [],
      nodes_by_parent: { "" => [root] }
    )
    result = Inamen::FileStatsReport::Result.new(
      rows: [Inamen::FileStatsReport::Row.new(key: :combined_total, label: "Total", count: 4)],
      total: 4,
      character_count: 12,
      seven_power: 7**7,
      explorer: explorer
    )

    snapshot = FileStatsStore.populate!(edition, result: result)
    loaded = FileStatsStore.load(edition)

    assert_equal snapshot.id, FileStatsStore.current_snapshot_for(edition).id
    assert_equal 4, loaded.total
    assert_equal 12, loaded.character_count
    assert_equal 2, loaded.explorer.root.word_count
    assert_equal 1, loaded.explorer.root.division_count
  ensure
    edition&.destroy
  end

  test "ignores stale snapshots after the edition checksum changes" do
    edition = create_store_edition("store_stale")
    root = Inamen::FileStatsExplorer::Node.new(
      node_id: "store_stale:edition",
      parent_id: nil,
      level: "edition",
      label: "store_stale",
      word_count: 0,
      number_count: 0,
      division_count: 0,
      character_count: 0,
      letter_count: 0,
      digit_count: 0,
      other_count: 0
    )
    result = Inamen::FileStatsReport::Result.new(rows: [], total: 0, character_count: 0, seven_power: 7**7,
                                                 explorer: Inamen::FileStatsExplorer::Result.new(
                                                   edition_id: edition.edition_id,
                                                   nodes: [root],
                                                   categories: [],
                                                   characters: [],
                                                   nodes_by_parent: { "" => [root] }
                                                 ))

    FileStatsStore.populate!(edition, result: result)
    edition.update!(source_checksum: "changed")

    assert_nil FileStatsStore.load(edition)
  ensure
    edition&.destroy
  end

  private

  def create_store_edition(short_name)
    path = Rails.root.join("tmp", "#{short_name}.txt")
    FileUtils.mkdir_p(path.dirname)
    File.write(path, "HOLY BIBLE\n")
    Edition.create!(
      short_name: short_name,
      name: short_name,
      corpus_type: "bible",
      source_path: path.to_s,
      source_filename: path.basename.to_s,
      source_checksum: Digest::SHA256.file(path).hexdigest,
      byte_size: path.size,
      imported_at: Time.current,
      metadata: {}
    )
  end
end
