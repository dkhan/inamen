# frozen_string_literal: true

RSpec.describe Inamen::KjvParseEvent do
  describe "kind registry" do
    it "lists every KIND_* constant exactly once in KINDS" do
      kind_const_values = described_class.constants(false)
        .select { |c| c.to_s.start_with?("KIND_") && c != :KINDS }
        .map { |c| described_class.const_get(c) }
      expect(kind_const_values.sort).to eq(described_class::KINDS.sort)
      expect(kind_const_values.uniq.size).to eq(described_class::KINDS.size)
    end
  end

  describe ".new" do
    let(:valid_attrs) do
      {
        kind: described_class::KIND_NUMBERED_LINE,
        lineno: 1,
        raw: "",
        stripped: "",
        totals_delta: {},
        book_chapters: 0,
        book_verses: 0,
        numeric_chapter_debug: nil,
        text_words_debug: nil,
        psalm_heading_debug: nil
      }
    end

    it "raises for an unknown kind when strict validation is on" do
      old = ENV["INAMEN_STRICT_PARSE_EVENT_KINDS"]
      ENV["INAMEN_STRICT_PARSE_EVENT_KINDS"] = "1"
      begin
        expect do
          described_class.new(**valid_attrs.merge(kind: :not_registered))
        end.to raise_error(ArgumentError, /Unknown KjvParseEvent kind/)
      ensure
        ENV["INAMEN_STRICT_PARSE_EVENT_KINDS"] = old
      end
    end
  end
end

RSpec.describe "KjvLineParser event stream" do
  it "emits only kinds registered on KjvParseEvent for the full KJV file" do
    kjv_path = File.expand_path("../../data/KJV.txt", __dir__)
    lines = File.readlines(kjv_path, chomp: true)
    kinds = []
    Inamen::KjvLineParser.each_event(lines) { |e| kinds << e.kind }

    unknown = kinds.uniq - Inamen::KjvParseEvent::KINDS
    expect(unknown).to be_empty, "unknown kinds: #{unknown.inspect}"
  end
end
