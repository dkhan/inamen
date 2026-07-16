# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::BookCategories do
  it "lists Protestant canon plus Apocrypha books" do
    expect(described_class.all_books.length).to eq(82)
    expect(described_class.all_books).to include("Genesis", "Revelation", "Tobit", "3 Maccabees")
  end

  it "groups books into categories" do
    ot_books = described_class.tree.flat_map { |t| t.categories.flat_map(&:books) if t.id == :ot }.compact
    nt_books = described_class.tree.flat_map { |t| t.categories.flat_map(&:books) if t.id == :nt }.compact
    apocrypha_books = described_class.tree.flat_map { |t| t.categories.flat_map(&:books) if t.id == :apocrypha }.compact
    expect(ot_books).to eq(described_class.ot_books)
    expect(nt_books).to eq(described_class.nt_books)
    expect(apocrypha_books).to eq(described_class.apocrypha_books)
    expect(ot_books + nt_books + apocrypha_books).to eq(described_class.all_books)
  end

  it "places Acts in NT Historical" do
    historical = described_class.books_for_category(:nt, :historical)
    expect(historical).to eq(["Acts"])
  end

  it "places Revelation in Apocalyptic only" do
    apocalyptic = described_class.books_for_category(:nt, :apocalyptic)
    general = described_class.books_for_category(:nt, :general_epistles)
    expect(apocalyptic).to eq(["Revelation"])
    expect(general).not_to include("Revelation")
    expect(general.last).to eq("Jude")
  end

  it "includes Hebrews in Pauline Epistles" do
    pauline = described_class.books_for_category(:nt, :pauline_epistles)
    expect(pauline).to include("Hebrews")
    expect(pauline).not_to include("James")
  end

  it "labels exact category book selections" do
    expect(described_class.label_for_books(%w[Matthew Mark Luke John])).to eq("Gospels")
    expect(described_class.label_for_books(["Acts"])).to eq("Historical")
    expect(described_class.label_for_books(described_class.books_for_category(:nt, :pauline_epistles)))
      .to eq("Pauline Epistles")
  end

  it "lists selected books when they do not fit a category" do
    expect(described_class.label_for_books(%w[Genesis Revelation])).to eq("Genesis, Revelation")
  end
end
