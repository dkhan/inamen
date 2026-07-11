# frozen_string_literal: true

RSpec.describe Inamen::FishermenGospelsKjs do
  describe ".load" do
    it "loads include and antimentions from the bundled KJS file" do
      data = described_class.load

      expect(data[:include_phrases]).to eq(%w[Peter* Thomas* Nathanael* James* John*])
      expect(data[:james_exclusions]).to include("James the son of Alphaeus")
      expect(data[:john_exclusions]).to include("John the Baptist")
      expect(data[:john_exclusions].any? { |phrase| phrase.include?("John\u2019s disciples") }).to be(true)
    end
  end
end
