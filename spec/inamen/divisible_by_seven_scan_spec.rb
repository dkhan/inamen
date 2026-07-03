# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe Inamen::DivisibleBySevenScan do
  before(:context) do
    path = File.expand_path("../../data/KJV.txt", __dir__)
    lines = File.readlines(path, chomp: true)
    @tmpdir = Dir.mktmpdir
    @db_path = File.join(@tmpdir, "kjv.sqlite")
    Inamen::CorpusStore.build!(lines, path: @db_path)
    @db = Inamen::CorpusStore.open(@db_path)
  end

  after(:context) do
    @db&.close
    FileUtils.remove_entry(@tmpdir) if @tmpdir
  end

  let(:db) { @db }

  describe ".count_for" do
    it "counts normalized token occurrences in a scope" do
      jesus = described_class.count_for(db, token: "Jesus")
      expect(jesus).to be > 900
      expect((jesus % 7).zero?).to be(false)
    end

    it "counts exact token_raw when exact: true" do
      lord = described_class.count_for(db, token: "Lord", exact: true)
      lord_caps = described_class.count_for(db, token: "LORD", exact: true)
      expect(lord).to be > 0
      expect(lord_caps).to be > 0
      expect(lord).not_to eq(lord_caps)
    end
  end

  describe ".scan" do
    it "returns tokens whose counts are divisible by 7" do
      rows = described_class.scan(db, divisible_by: 7, scope: :whole_bible, min_count: 7)
      expect(rows).not_to be_empty
      expect(rows).to all(satisfy { |r| (r.count % 7).zero? })
    end

    it "filters by testament scope" do
      ot = described_class.scan(db, divisible_by: 7, scope: :ot, min_count: 14)
      nt = described_class.scan(db, divisible_by: 7, scope: :nt, min_count: 14)
      expect(ot).not_to eq(nt)
    end
  end
end
