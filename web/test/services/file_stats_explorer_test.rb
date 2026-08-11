# frozen_string_literal: true

require "test_helper"

class FileStatsExplorerTest < ActiveSupport::TestCase
  test "counts the full Matthew gospel title after a New Testament header" do
    lines = [
      "THE",
      "NEW TESTAMENT",
      "OF OUR LORD AND SAVIOR",
      "JESUS CHRIST",
      "",
      "THE GOSPEL ACCORDING TO",
      "ST. MATTHEW",
      "",
      "CHAPTER 1",
      "THE book of the generation of Jesus Christ, the son of David, the son of Abraham."
    ]

    nodes, = Inamen::FileStatsExplorer.build_nodes_and_char_counts(
      "title_after_nt_header",
      {},
      lines,
      "#{lines.join("\n")}\n"
    )

    title = nodes.find { |node| node.node_id == "title_after_nt_header:book_title:Matthew" }

    assert_not_nil title
    assert_equal 4, title.word_count
    assert_equal 20, title.letter_count
  end

  test "keeps the leading article of John's gospel title on the gospels category" do
    lines = [
      "THE GOSPEL ACCORDING TO",
      "ST. JOHN",
      "",
      "CHAPTER 1",
      "IN the beginning was the Word, and the Word was with God, and the Word was God."
    ]

    nodes, = Inamen::FileStatsExplorer.build_nodes_and_char_counts(
      "john_gospel_title",
      {},
      lines,
      "#{lines.join("\n")}\n"
    )

    title = nodes.find { |node| node.node_id == "john_gospel_title:book_title:John" }
    book = nodes.find { |node| node.node_id == "john_gospel_title:book:John" }
    gospels = nodes.find { |node| node.node_id == "john_gospel_title:category:NT:gospels" }

    assert_not_nil title
    assert_not_nil book
    assert_not_nil gospels
    assert_equal 3, title.word_count
    assert_equal 17, title.letter_count
    assert_equal 23, book.letter_count - nodes.select { |node| node.parent_id == book.node_id && node.level == "chapter" }.sum(&:letter_count)
    assert_equal 3, gospels.letter_count - book.letter_count
  end
end
