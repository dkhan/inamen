# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::FileStatsReport do
  describe ".build" do
    let(:lines) { Inamen::KjvFixture.lines }

    it "matches the 7^7 breakdown totals" do
      result = described_class.build(lines, text_path: "")

      expect(result.total).to eq(823_543)
      expect(result.seven_power).to eq(7**7)

      by_key = result.rows.to_h { |row| [row.key, row.count] }
      expect(by_key[:verse_text_words]).to eq(789_629)
      expect(by_key[:psalm_heading_words]).to eq(1034)
      expect(by_key[:colophon_words]).to eq(186)
      expect(by_key[:total_chapters]).to eq(1189)
      expect(by_key[:total_verses]).to eq(31_102)
      expect(by_key[:psalm_119_inscriptions]).to eq(22)
      expect(by_key[:cover_and_titles]).to eq(381)
    end

    it "matches the canonical breakdown for punctuation-less KJV headings with an NT header" do
      text_path = File.expand_path("../../data/KJV-HEBREW.txt", __dir__)
      skip "KJV Hebrew sample text missing" unless File.file?(text_path)

      processed = Inamen::BibleTextPreprocessor.from_file(text_path)
      source_lines = File.readlines(text_path, chomp: true, encoding: "UTF-8")
      result = described_class.build(processed.lines, text_path: text_path, source_lines: source_lines)
      by_key = result.rows.to_h { |row| [row.key, row.count] }

      expect(result.total).to eq(823_543)
      expect(by_key[:verse_text_words]).to eq(789_629)
      expect(by_key[:total_chapters]).to eq(1189)
      expect(by_key[:total_verses]).to eq(31_102)
      expect(by_key[:cover_and_titles]).to eq(381)
    end

    it "counts Authorized Version cover text for PCE-style sources" do
      text_path = File.expand_path("../../data/KJB-PCE-RTF.txt", __dir__)
      skip "KJB PCE RTF sample text missing" unless File.file?(text_path)

      processed = Inamen::BibleTextPreprocessor.from_file(text_path)
      source_lines = File.readlines(text_path, chomp: true, encoding: "UTF-8")
      result = described_class.build(processed.lines, text_path: text_path, source_lines: source_lines)
      by_key = result.rows.to_h { |row| [row.key, row.count] }

      expect(result.total).to eq(823_543)
      expect(by_key[:verse_text_words]).to eq(789_630)
      expect(by_key[:cover_and_titles]).to eq(380)
    end

    it "counts Oxford cover text toward the 7^7 total" do
      text_path = File.expand_path("../../data/KJV_OXFORD.txt", __dir__)
      skip "KJV Oxford sample text missing" unless File.file?(text_path)

      processed = Inamen::BibleTextPreprocessor.from_file(text_path)
      source_lines = File.readlines(text_path, chomp: true, encoding: "UTF-8")
      result = described_class.build(processed.lines, text_path: text_path, source_lines: source_lines)
      by_key = result.rows.to_h { |row| [row.key, row.count] }

      expect(result.total).to eq(result.rows.sum(&:count))
      expect(by_key[:cover_and_titles]).to be >= 381
    end
  end

  describe ".character_count_for" do
    it "returns UTF-8 codepoint length for a text file" do
      path = File.expand_path("../../data/KJV.txt", __dir__)
      skip "sample text missing" unless File.file?(path)

      expect(described_class.character_count_for(path)).to eq(4_233_726)
    end
  end
end
