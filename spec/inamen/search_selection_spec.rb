# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::SearchSelection do
  before(:context) do
    @db = Inamen::KjvFixture.db
  end

  let(:db) { @db }

  describe ".default" do
    it "includes all scannable text" do
      selection = described_class.default
      expect(selection.colophons).to be(true)
      expect(selection.superscriptions).to be(true)
      expect(selection.books).to eq(Inamen::BookCategories.all_books)
      expect(selection.label).to eq("whole Bible")
    end
  end

  describe ".from_legacy" do
    it "matches whole_bible default bucket" do
      legacy = described_class.from_legacy(scope: :whole_bible, bucket: :default)
      default = described_class.default
      expect(count_jesus(legacy)).to eq(count_jesus(default))
    end

    it "matches OT scope" do
      legacy = described_class.from_legacy(scope: :ot, bucket: :default)
      ot_books = Inamen::BookCategories.ot_books
      expect(legacy.books).to eq(ot_books)
      expect(legacy.colophons).to be(true)
      expect(legacy.superscriptions).to be(true)
    end

    it "matches verse_text only bucket" do
      legacy = described_class.from_legacy(scope: :whole_bible, bucket: :verse_text)
      expect(legacy.colophons).to be(false)
      expect(legacy.superscriptions).to be(false)
      expect(legacy.books).to eq(Inamen::BookCategories.all_books)
    end
  end

  describe ".from_params" do
    it "parses submitted checkbox state" do
      selection = described_class.from_params(
        submitted: "1",
        colophons: "0",
        superscriptions: "1",
        books: %w[Matthew Mark]
      )
      expect(selection.colophons).to be(false)
      expect(selection.superscriptions).to be(true)
      expect(selection.books).to eq(%w[Matthew Mark])
      expect(selection.label).to eq("superscriptions, 2 books")
    end

    it "treats compact all_books submit as default whole Bible" do
      selection = described_class.from_params(submitted: "1", all_books: "1")
      expect(selection.default?).to be(true)
    end

    it "keeps verse-text scope when colophons and superscriptions are explicitly off" do
      selection = described_class.from_params(
        submitted: "1",
        all_books: "1",
        colophons: "0",
        superscriptions: "0"
      )
      expect(selection.colophons).to be(false)
      expect(selection.superscriptions).to be(false)
      expect(selection.default?).to be(false)
    end

    it "treats checkbox plus hidden submit values as checked" do
      selection = described_class.from_params(
        submitted: "1",
        all_books: "1",
        colophons: %w[0 1],
        superscriptions: "0"
      )
      expect(selection.colophons).to be(true)
      expect(selection.superscriptions).to be(false)
    end
  end

  describe "#where_clause" do
    it "returns no rows for empty selection" do
      selection = described_class.new(colophons: false, superscriptions: false, books: [])
      sql, params = selection.where_clause
      expect(sql).to include("1=0")
      expect(params).to eq([])
    end
  end

  def count_jesus(selection)
    Inamen::TokenQuery.scan(
      db,
      terms: [Inamen::TokenQuery::QueryTerm.new(pattern: "jesus", case_sensitive: false)],
      search_selection: selection
    ).first.count
  end
end
