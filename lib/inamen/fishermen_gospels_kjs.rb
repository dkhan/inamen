# frozen_string_literal: true

module Inamen
  # KJPBS search criteria for the John 21 fishing-party name count (Gospels).
  # Source: data/features/fishermen_gospels.kjs
  module FishermenGospelsKjs
    KJS_PATH = File.expand_path("../../data/features/fishermen_gospels.kjs", __dir__).freeze

    INCLUDE_PHRASES = %w[Peter* Thomas* Nathanael* James* John*].freeze

    class << self
      def load
        @load ||= parse_file(KJS_PATH)
      end

      def james_exclusions
        load[:james_exclusions]
      end

      def john_exclusions
        load[:john_exclusions]
      end

      def james_exclude_phrase
        load[:james_exclude_phrase]
      end

      def john_exclude_phrase
        load[:john_exclude_phrase]
      end

      def antimention_parts(phrase)
        parts = split_alternatives(phrase.to_s)
        parts = parts.drop(1) if parts.first&.match?(/\AANTIMENTIONS OF /i)
        parts
      end

      def reload!
        @load = nil
        load
      end

      private

      def parse_file(path)
        raise "Missing KJS file: #{path}" unless File.file?(path)

        phrases = {}
        File.readlines(path, chomp: true).each do |line|
          next unless (match = line.match(/\A(\d+)\\Phrase=(.+)\z/))

          index = match[1].to_i
          text = match[2].delete_prefix('"').delete_suffix('"')
          phrases[index] = decode_phrase(text)
        end

        james_raw = phrases.fetch(6)
        john_raw = phrases.fetch(7)
        james_parts = split_alternatives(james_raw).drop(1) # drop antimention label
        john_parts = split_alternatives(john_raw).drop(1)

        {
          include_phrases: INCLUDE_PHRASES,
          james_exclude_phrase: james_raw,
          john_exclude_phrase: john_raw,
          james_exclusions: james_parts,
          john_exclusions: john_parts
        }
      end

      def decode_phrase(text)
        text.gsub(/\\x([0-9a-fA-F]{2,4})/) { [::Regexp.last_match(1).to_i(16)].pack("U") }
      end

      def split_alternatives(text)
        TokenPattern.split_phrase_patterns(text)
      rescue ArgumentError
        text.split("|").map(&:strip).reject(&:empty?)
      end
    end
  end
end
