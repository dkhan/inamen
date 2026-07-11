# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::PhraseCompleter do
  let(:words) { %w[Jesui Jesuites Jesurun JESUS Jesus Christ jeroboam] }
  let(:completer) { described_class.new(words: words) }

  describe "#analyze" do
    it "marks a partial word invalid and suggests completions" do
      result = completer.analyze("jesu")

      expect(result.can_search).to be(false)
      expect(result.suggestions).to include("Jesui", "Jesus")
      expect(result.branches.first.preview.map(&:text)).to eq(["jesu"])
      expect(result.branches.first.preview.first.valid).to be(false)
    end

    it "accepts a complete valid word" do
      result = completer.analyze("Jesus")

      expect(result.can_search).to be(true)
      expect(result.branches.first.preview.first.valid).to be(true)
    end

    it "accepts a valid multi-word phrase" do
      result = completer.analyze("Jesus Christ")

      expect(result.can_search).to be(true)
      expect(result.branches.first.preview.all?(&:valid)).to be(true)
    end

    it "does not strike through a wildcard partial that already matches" do
      words = %w[Amen Amethyst Jesus]
      completer = described_class.new(words: words)
      result = completer.analyze("Ame*")

      expect(result.branches.first.preview.first.valid).to be(true)
      expect(result.can_search).to be(true)
    end

    it "accepts jesu* as a searchable wildcard" do
      words = %w[Jesui Jesuites JESUS Jesus]
      completer = described_class.new(words: words)
      result = completer.analyze("jesu*")

      expect(result.can_search).to be(true)
      expect(result.branches.first.preview.first.valid).to be(true)
    end

    it "accepts ASCII spellings of ligature dictionary words in phrases" do
      words = ["James", "the", "son", "of", "Alph\u00e6us"]
      completer = described_class.new(words: words)
      result = completer.analyze("James the son of Alphaeus")

      expect(result.can_search).to be(true)
      expect(result.branches.first.preview.map(&:text)).to eq(%w[James the son of Alphaeus])
      expect(result.branches.first.preview.all?(&:valid)).to be(true)
    end
  end
end
