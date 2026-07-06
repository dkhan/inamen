# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::TokenPattern do
  describe ".parse_line" do
    it "parses plain patterns as case-insensitive" do
      expect(described_class.parse_line("six")).to eq(pattern: "six", case_sensitive: false)
    end

    it "parses |cs suffix as case-sensitive" do
      expect(described_class.parse_line("six|cs")).to eq(pattern: "six", case_sensitive: true)
    end

    it "returns nil for blank lines" do
      expect(described_class.parse_line("  ")).to be_nil
    end
  end

  describe ".matches?" do
    it "matches whole tokens for exact case-sensitive patterns" do
      expect(described_class.matches?("six", token_raw: "six", token_norm: "six", case_sensitive: true)).to be(true)
      expect(described_class.matches?("six", token_raw: "Six", token_norm: "six", case_sensitive: true)).to be(false)
      expect(described_class.matches?("six", token_raw: "Sixteen", token_norm: "sixteen", case_sensitive: true)).to be(false)
      expect(described_class.matches?("six", token_raw: "twenty-six", token_norm: "twenty-six", case_sensitive: true)).to be(false)
    end

    it "matches normalized spellings for exact case-insensitive patterns" do
      expect(described_class.matches?("six", token_raw: "Six", token_norm: "six", case_sensitive: false)).to be(true)
      expect(described_class.matches?("six", token_raw: "Sixteen", token_norm: "sixteen", case_sensitive: false)).to be(false)
    end

    it "matches wildcard patterns within a token" do
      curly = "Jesus\u{2019}"
      expect(described_class.matches?("*jesus*", token_raw: "Bar-jesus", token_norm: "bar-jesus", case_sensitive: false)).to be(true)
      expect(described_class.matches?("*jesus*", token_raw: "Jesus", token_norm: "jesus", case_sensitive: false)).to be(true)
      expect(described_class.matches?("*jesus*", token_raw: "JESUS", token_norm: "jesus", case_sensitive: false)).to be(true)
      expect(described_class.matches?("*jesus*", token_raw: curly, token_norm: "jesus\u{2019}", case_sensitive: false)).to be(true)
      expect(described_class.matches?("jesus*", token_raw: curly, token_norm: "jesus\u{2019}", case_sensitive: false)).to be(true)
      expect(described_class.matches?("*Jesus\u{2019}", token_raw: curly, token_norm: "jesus\u{2019}", case_sensitive: false)).to be(true)
      expect(described_class.matches?("*jesus*", token_raw: "Ephesus", token_norm: "ephesus", case_sensitive: false)).to be(false)
    end

    it "does not let wildcards match across punctuation inside a token" do
      expect(described_class.matches?("jesus*", token_raw: "Jesus\u{2019}s", token_norm: "jesus\u{2019}s", case_sensitive: false)).to be(false)
    end

    it "builds SQL prefilters from wildcard patterns" do
      expect(described_class.sql_prefilter("*jesus*", case_sensitive: false)).to eq(
        op: :like, column: "token_norm", value: "%jesus%"
      )
      expect(described_class.sql_prefilter("jesus*", case_sensitive: false)).to eq(
        op: :like, column: "token_norm", value: "jesus%"
      )
      expect(described_class.sql_prefilter("*jesus", case_sensitive: false)).to eq(
        op: :like, column: "token_norm", value: "%jesus"
      )
      expect(described_class.sql_prefilter("*jesus*", case_sensitive: true)).to eq(
        op: :glob, column: "token_raw", value: "*jesus*"
      )
    end

    it "treats ASCII and curly apostrophes as equivalent in exact patterns" do
      curly = "Jesus\u{2019}"
      expect(described_class.matches?("jesus'", token_raw: curly, token_norm: "jesus\u{2019}", case_sensitive: false)).to be(true)
      expect(described_class.matches?("jesus", token_raw: curly, token_norm: "jesus\u{2019}", case_sensitive: false)).to be(false)
    end
  end
end
