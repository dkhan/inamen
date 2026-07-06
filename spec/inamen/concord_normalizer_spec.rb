# frozen_string_literal: true

RSpec.describe Inamen::ConcordNormalizer do
  describe ".normalize" do
    it "title-cases implicit verse 1 after CHAPTER lines" do
      lines = [
        "CHAPTER 8",
        "IN those days the multitude being very great, and having nothing to eat, Jesus called his disciples unto him, and saith unto them,",
        "2 I have compassion on the multitude,"
      ]

      normalized = described_class.normalize(lines)

      expect(normalized[1]).to eq(
        "In those days the multitude being very great, and having nothing to eat, Jesus called his disciples unto him, and saith unto them,"
      )
      expect(normalized[2]).to eq(lines[2])
    end

    it "normalizes JESUS to Jesus on implicit John 8:1" do
      lines = [
        "CHAPTER 8",
        "JESUS went unto the mount of Olives.",
        "2 And early in the morning he came again into the temple,"
      ]

      normalized = described_class.normalize(lines)

      expect(normalized[1]).to eq("Jesus went unto the mount of Olives.")
    end

    it "leaves numbered verse lines unchanged" do
      lines = ["8", "1 In those days the multitude being very great,"]

      expect(described_class.normalize(lines)).to eq(lines)
    end
  end
end
