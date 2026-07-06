# frozen_string_literal: true

module Inamen
  # KJPBS-style token patterns: * wildcards within a single token; whole-token match otherwise.
  module TokenPattern
    MAX_LENGTH = 120
    CASE_SUFFIX = /\|cs\z/i
    DISABLED_SUFFIX = /\|disabled\z/i
    # Letters, digits, hyphen — not punctuation, space, or newline.
    WILDCARD_FRAGMENT = "(?:[\\p{L}\\p{M}0-9\\-]*)"
    TRAILING_POSSESSIVE = /['\u{2019}]\z/

    class << self
      def wildcard?(pattern)
        pattern.include?("*")
      end

      def validate!(pattern)
        raise ArgumentError, "pattern cannot be empty" if pattern.to_s.empty?
        raise ArgumentError, "pattern too long (max #{MAX_LENGTH})" if pattern.length > MAX_LENGTH

        pattern
      end

      def parse_line(line)
        stripped = line.to_s.strip
        return nil if stripped.empty?

        case_sensitive = false
        if (match = stripped.match(CASE_SUFFIX))
          case_sensitive = true
          stripped = stripped[0...match.begin(0)].strip
        end

        return nil if stripped.empty?

        { pattern: stripped, case_sensitive: case_sensitive }
      end

      def split_phrase_patterns(pattern)
        pattern.to_s.split("|").map(&:strip).reject(&:empty?).each { |part| validate!(part) }
      end

      def parse_query_line(line)
        stripped = line.to_s.strip
        return nil if stripped.empty?

        disabled = false
        if (match = stripped.match(DISABLED_SUFFIX))
          disabled = true
          stripped = stripped[0...match.begin(0)].strip
        end
        return nil if stripped.empty?

        attrs = parse_line(stripped)
        return nil unless attrs

        attrs.merge(disabled: disabled)
      end

      def matches?(pattern, token_raw:, token_norm:, case_sensitive:)
        validate!(pattern)
        if wildcard?(pattern)
          wildcard_match?(pattern, token_raw: token_raw, token_norm: token_norm, case_sensitive: case_sensitive)
        else
          exact_match?(pattern, token_raw: token_raw, token_norm: token_norm, case_sensitive: case_sensitive)
        end
      end

      def to_regex(pattern, case_sensitive:)
        parts = CorpusStore.normalize_apostrophes(pattern).split("*", -1)
        source = parts.map { |part| Regexp.escape(part) }.join(WILDCARD_FRAGMENT)
        flags = case_sensitive ? 0 : Regexp::IGNORECASE
        Regexp.new("\\A#{source}\\z", flags)
      end

      # SQL prefilter for wildcard patterns (refined in Ruby with #matches?).
      def sql_prefilter(pattern, case_sensitive:)
        return :full if pattern.gsub("*", "").empty?

        if case_sensitive
          { op: :glob, column: "token_raw", value: build_glob(pattern) }
        else
          parts = CorpusStore.normalize_apostrophes(pattern).split("*", -1).map do |part|
            escape_like(CorpusStore.normalize_token(part))
          end
          { op: :like, column: "token_norm", value: parts.join("%") }
        end
      end

      def build_glob(pattern)
        CorpusStore.normalize_apostrophes(pattern).split("*", -1).map { |part| escape_glob(part) }.join("*")
      end

      def escape_like(str)
        str.gsub("\\", "\\\\").gsub("%", "\\%").gsub("_", "\\_")
      end

      def escape_glob(str)
        str.gsub(/([\[\]\?*])/, '[\\1]')
      end

      def strip_trailing_possessive_for_wildcard?(pattern)
        !CorpusStore.normalize_apostrophes(pattern).gsub("*", "").match?(/['\u{2019}]/)
      end

      private

      def exact_match?(pattern, token_raw:, token_norm:, case_sensitive:)
        return false if possessive_excluded?(pattern, token_raw)

        raw = CorpusStore.normalize_apostrophes(token_raw)
        norm = CorpusStore.normalize_apostrophes(token_norm)

        if case_sensitive
          raw == CorpusStore.normalize_apostrophes(pattern)
        else
          norm == CorpusStore.normalize_token(pattern)
        end
      end

      def wildcard_match?(pattern, token_raw:, token_norm:, case_sensitive:)
        raw = CorpusStore.normalize_apostrophes(token_raw)
        norm = CorpusStore.normalize_apostrophes(token_norm)
        text = wildcard_match_text(case_sensitive ? raw : norm, pattern)
        to_regex(pattern, case_sensitive: case_sensitive).match?(text)
      end

      def wildcard_match_text(text, pattern)
        text = CorpusStore.normalize_apostrophes(text)
        return text unless strip_trailing_possessive_for_wildcard?(pattern)

        text.sub(TRAILING_POSSESSIVE, "")
      end

      def possessive_excluded?(pattern, token_raw)
        return false if pattern.match?(/['\u{2019}]/)

        token_raw.end_with?("'", "\u{2019}")
      end
    end
  end
end
