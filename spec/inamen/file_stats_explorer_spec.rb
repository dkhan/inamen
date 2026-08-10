# frozen_string_literal: true

require "spec_helper"
require "fileutils"

RSpec.describe Inamen::FileStatsExplorer do
  let(:edition_id) { "explorer_spec" }
  let(:checksum) { "abc123" }
  let(:chapter_index) do
    {
      "Genesis" => {
        1 => {
          1 => "In 1 beginning.",
          2 => "Æon\nGod's 7"
        }
      },
      "Matthew" => {
        1 => {
          1 => "Jesus 12"
        }
      }
    }
  end
  let(:source_text) do
    [
      "HOLY BIBLE\n",
      "KING JAMES VERSION\n",
      "\n",
      "Genesis\n",
      "CHAPTER 1\n",
      "1 In 1 beginning.\n",
      "2 Æon\nGod's 7\n",
      "THE\n",
      "NEW TESTAMENT\n",
      "OF OUR LORD AND SAVIOR\n",
      "JESUS CHRIST\n",
      "Matthew\n",
      "CHAPTER 1\n",
      "1 Jesus 12\n"
    ].join
  end
  let(:lines) { source_text.lines(chomp: true) }

  after do
    FileUtils.rm_rf(described_class.cache_dir(edition_id))
  end

  it "generates CSV cache files and loads the explorer" do
    result = described_class.resolve(edition_id, checksum: checksum, chapter_index: chapter_index, lines:, source_text:, force: true)
    dir = described_class.cache_dir(edition_id)

    expect(File).to exist(File.join(dir, "manifest.csv"))
    expect(File).to exist(File.join(dir, "structure_nodes.csv"))
    expect(File).to exist(File.join(dir, "character_categories.csv"))
    expect(File).to exist(File.join(dir, "characters.csv"))
    source_tokens = Inamen::Tokenizer.tokenize(source_text)
    expect(result.root.word_count).to eq(source_tokens.count { |token| !token.match?(/\A[0-9]+\z/) })
    expect(result.root.number_count).to eq(source_tokens.count { |token| token.match?(/\A[0-9]+\z/) })
    expect(result.root.character_count).to eq(source_text.length)
    expect(result.children_of(result.root.node_id).map(&:label)).to include("Source text outside canon", "Old Testament", "New Testament")
    title = result.children_of(result.root.node_id).find { |node| node.label == "Source text outside canon" }
    expect(result.children_of(title.node_id).map(&:label)).to include(
      "Bible name",
      "Version"
    )
    nt = result.children_of(result.root.node_id).find { |node| node.label == "New Testament" }
    expect(result.children_of(nt.node_id).map(&:label)).to include("New Testament header")
  end

  it "reuses current cache until the checksum changes" do
    described_class.resolve(edition_id, checksum: checksum, chapter_index: chapter_index, lines:, source_text:, force: true)
    path = File.join(described_class.cache_dir(edition_id), "structure_nodes.csv")
    first_mtime = File.mtime(path)

    described_class.resolve(edition_id, checksum: checksum, chapter_index: chapter_index, lines:, source_text:)
    expect(File.mtime(path)).to eq(first_mtime)

    sleep 1
    described_class.resolve(edition_id, checksum: "changed", chapter_index: chapter_index, lines:, source_text:)
    expect(File.mtime(path)).to be > first_mtime
  end

  it "keeps parent structure totals equal to child sums" do
    result = described_class.resolve(edition_id, checksum: checksum, chapter_index: chapter_index, lines:, source_text:, force: true)

    result.nodes.select { |node| result.children_of(node.node_id).any? }.each do |node|
      children = result.children_of(node.node_id)
      expect(node.word_count).to eq(children.sum(&:word_count))
      expect(node.number_count).to eq(children.sum(&:number_count))
      expect(node.division_count).to eq(children.sum(&:division_count))
      expect(node.character_count).to eq(children.sum(&:character_count))
    end
  end

  it "counts Latin Psalm 119 stanza labels as words" do
    kjv_edition = "explorer_kjv_psalm_119"
    kjv_source = File.read(Inamen::KjvFixture::KJV_PATH, encoding: "UTF-8")
    result = described_class.resolve(
      kjv_edition,
      checksum: "kjv-psalm-119",
      chapter_index: Inamen::VerseIndex.build_chapter_index(Inamen::KjvFixture.lines),
      lines: Inamen::KjvFixture.lines,
      source_text: kjv_source,
      force: true
    )

    psalm_119 = result.nodes.find { |node| node.book == "Psalms" && node.chapter == 119 && node.label == "Hebrew letters" }

    expect(psalm_119.word_count).to eq(22)
    expect(psalm_119.division_count).to eq(0)
    expect(result.root.word_count + result.root.number_count + result.root.division_count).to eq(823_543)
  ensure
    FileUtils.rm_rf(described_class.cache_dir(kjv_edition)) if kjv_edition
  end

  it "classifies character categories and individual characters" do
    result = described_class.resolve(edition_id, checksum: checksum, chapter_index: chapter_index, lines:, source_text:, force: true)
    root_id = result.root.node_id
    categories = result.categories_for(root_id).to_h { |row| [[row.category, row.subcategory], row.count] }
    chars = result.characters_for(root_id).to_h { |row| [row.char, row.count] }

    top_level_total = result.categories_for(root_id).select { |row| row.subcategory == "total" }.sum(&:count)
    expect(top_level_total).to eq(source_text.length)
    expect(categories.fetch(["letters", "total"])).to be_positive
    expect(categories.fetch(["letters", "other_letters"])).to eq(1)
    expect(categories.fetch(["digits", "total"])).to eq(source_text.each_char.count { |char| char.match?(/\p{Nd}/) })
    expect(categories.fetch(["punctuation", "total"])).to be >= 2
    expect(categories.fetch(["whitespace", "newline"])).to eq(source_text.count("\n"))
    expect(chars.fetch("Æ")).to eq(1)
    expect(chars.fetch("\n")).to eq(source_text.count("\n"))
  end

  it "loads character breakdowns for individual structure nodes" do
    result = described_class.resolve(edition_id, checksum: checksum, chapter_index: chapter_index, lines:, source_text:, force: true)
    nt = result.children_of(result.root.node_id).find { |node| node.label == "New Testament" }
    gospels = result.children_of(nt.node_id).find { |node| node.label == "Gospels" }

    breakdown = result.character_breakdown_for(gospels.node_id)
    categories = breakdown.fetch(:categories).to_h { |row| [[row.category, row.subcategory], row.count] }
    chars = breakdown.fetch(:characters).to_h { |row| [row.char, row.count] }

    expect(categories.fetch(["letters", "total"])).to eq(gospels.letter_count)
    expect(categories.fetch(["digits", "total"])).to eq(gospels.digit_count)
    expect(chars.fetch("J")).to eq(1)
  end
end
