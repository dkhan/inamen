# frozen_string_literal: true

module Inamen
  # Physical-line normalization shared by the parser and classifiers.
  module KjvLine
    # Strip surrounding whitespace and a leading pilcrow (¶) used in some KJV editions.
    def self.strip(line)
      line.to_s.strip.sub(/\A¶\s*/, "")
    end
  end
end
