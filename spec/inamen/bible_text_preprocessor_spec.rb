# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Inamen::BibleTextPreprocessor do
  def with_text_file(text)
    file = Tempfile.new(["edition", ".txt"])
    file.write(text)
    file.close
    yield file.path
  ensure
    file&.unlink
  end

  it "trims outside matter and keeps Bible structure including Apocrypha" do
    text = <<~TEXT
      Publisher introduction

      Genesis
      Chapter 1
      In the beginning God created the heaven and the earth.
      2 And the earth was without form.
      A Psalm of David.
      [The end of Genesis.]

      Tobit
      1
      1 The book of the words of Tobit.

      Back matter
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)

      expect(result.books).to eq(["Genesis", "Tobit"])
      expect(result.lines).to include("Genesis", "CHAPTER 1", "Tobit", "1")
      expect(result.lines).to include("In the beginning God created the heaven and the earth.")
      expect(result.lines).not_to include("Publisher introduction")
      expect(result.lines).not_to include("Back matter")
    end
  end

  it "keeps Psalm chapter titles, superscriptions, and implicit verse openings" do
    text = <<~TEXT
      Psalms
      PSALM 1
      Blessed is the man that walketh not in the counsel of the ungodly.
      2 But his delight is in the law of the LORD.

      PSALM 2
      A Psalm of David.
      Why do the heathen rage?
      2 The kings of the earth set themselves.
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)

      expect(result.books).to eq(["Psalms"])
      expect(result.lines).to include("PSALM 1", "PSALM 2")
      expect(result.lines).to include("A Psalm of David.")
      expect(result.lines).to include("Blessed is the man that walketh not in the counsel of the ungodly.")
      expect(result.lines).to include("Why do the heathen rage?")
    end
  end

  it "rejects binary files" do
    with_text_file("Genesis\x00Chapter 1") do |path|
      expect { described_class.from_file(path) }.to raise_error(described_class::Error, /binary/)
    end
  end

  it "rejects invalid UTF-8" do
    file = Tempfile.new(["edition", ".txt"])
    file.binmode
    file.write("\xC3\x28")
    file.close

    expect { described_class.from_file(file.path) }.to raise_error(described_class::Error, /encoding/)
  ensure
    file&.unlink
  end
end
