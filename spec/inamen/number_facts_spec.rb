# frozen_string_literal: true

require "inamen/number_facts"

RSpec.describe Inamen::NumberFacts do
  describe ".build" do
    it "searches one million fractional digits of Pi and Phi by default" do
      expect(described_class::DEFAULT_SEQUENCE_DIGITS).to eq(1_000_000)
    end

    it "reports prime factors with prime indexes" do
      facts = described_class.build(1029, sequence_digits: 100)

      expect(facts.factors.map { |factor| [factor.prime, factor.exponent, factor.prime_index] })
        .to eq([[3, 1, 2], [7, 3, 4]])
      expect(facts.seven[:exponent]).to eq(3)
      expect(facts.seven[:cofactor]).to eq(3)
    end

    it "reports balanced seven forms and divisor classification" do
      facts = described_class.build(980, sequence_digits: 100)

      expect(facts.seven[:balanced_sum]).to eq("490 + 490 = 70x7 + 70x7")
      expect(facts.divisor_count).to eq(18)
      expect(facts.classification).to eq("abundant")
    end

    it "finds digit occurrences in Pi and Phi" do
      facts = described_class.build(141, sequence_digits: 50)

      pi = facts.sequences.find { |sequence| sequence.name == "Pi" }
      phi = facts.sequences.find { |sequence| sequence.name == "Phi" }

      expect(pi.position).to eq(1)
      expect(pi.position_for(1)).to eq(1)
      expect(pi.position_for(7)).to be_nil
      expect(phi.searched_digits).to eq(50)
    end

    it "finds the 777th occurrence of 913 in Phi at 823543" do
      facts = described_class.build(913)
      phi = facts.sequences.find { |sequence| sequence.name == "Phi" }

      expect(phi.position_for(777)).to eq(823_543)
    end
  end

  describe ".pi_digits and .phi_digits" do
    it "generates known decimal prefixes" do
      expect(described_class.pi_digits(10)).to eq("1415926535")
      expect(described_class.phi_digits(10)).to eq("6180339887")
    end

    it "generates longer Pi prefixes with the Chudnovsky implementation" do
      expect(described_class.pi_digits(50)).to eq("14159265358979323846264338327950288419716939937510")
    end
  end
end
