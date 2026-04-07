# frozen_string_literal: true

RSpec.describe Inamen::Tokenizer do
  describe ".tokenize" do
    it "splits punctuation from words and preserves case" do
      input = "And God said, Let there be light."
      expect(described_class.tokenize(input)).to eq(
        %w[And God said Let there be light]
      )
    end

    it "keeps apostrophes and hyphens inside words and supports Unicode letters" do
      input = "archæology God's well-being"
      expect(described_class.tokenize(input)).to eq(
        %w[archæology God's well-being]
      )
    end

    it "returns empty array for nil or blank" do
      expect(described_class.tokenize(nil)).to eq([])
      expect(described_class.tokenize("")).to eq([])
      expect(described_class.tokenize("   \n\t  ")).to eq([])
    end

    it "emits numeric tokens as separate tokens" do
      expect(described_class.tokenize("In 1492 Columbus sailed")).to eq(
        %w[In 1492 Columbus sailed]
      )
    end
  end
end
