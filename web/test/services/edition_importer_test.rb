# frozen_string_literal: true

require "test_helper"
require "tempfile"

class EditionImporterTest < ActiveSupport::TestCase
  test "imports a local Bible text and builds an edition row" do
    file = Tempfile.new(["sample-edition", ".txt"])
    file.write(<<~TEXT)
      Front matter

      Genesis
      Chapter 1
      1 In the beginning God created the heaven and the earth.

      Tobit
      1
      1 The book of the words of Tobit.

      Publisher note
    TEXT
    file.close

    result = EditionImporter.import!(file: file.path, type: "bible", name: "Sample Import", force: true)

    assert_predicate result.edition, :persisted?
    assert_equal "sample_import", result.edition.short_name
    assert_equal %w[Genesis Tobit], result.edition.metadata["books"]
    assert_nil result.edition.metadata["processed_path"]
    assert_equal File.expand_path(file.path), result.edition.source_path
    assert File.file?(result.paths.fetch(:corpus))
    assert File.file?(result.paths.fetch(:word_stream))
  ensure
    file&.unlink
  end
end
