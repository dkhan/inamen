# frozen_string_literal: true

module Inamen
  # One emitted item per non-empty line from KjvLineParser — normalized "event" plus aggregates for totals/book stats.
  # New kinds: add a KIND_* constant, append it to KINDS, and use it from KjvLineParser only.
  class KjvParseEvent < Struct.new(
    :kind,
    :lineno,
    :raw,
    :stripped,
    :totals_delta,
    :book_chapters,
    :book_verses,
    :numeric_chapter_debug,
    :text_words_debug,
    :psalm_heading_debug,
    keyword_init: true
  )
    KIND_SPLIT_VERSE_BODY = :split_verse_body
    KIND_PSALM_119_DIVISION = :psalm_119_division
    KIND_PSALM_TITLE = :psalm_title
    KIND_PSALM_HEADING = :psalm_heading
    KIND_VERSE_AFTER_PSALM_HEADING = :verse_after_psalm_heading
    KIND_IMPLICIT_PSALM_OPENING = :implicit_psalm_opening
    KIND_SPLIT_VERSE_NUMBER = :split_verse_number
    KIND_NUMBERED_LINE = :numbered_line

    KINDS = [
      KIND_SPLIT_VERSE_BODY,
      KIND_PSALM_119_DIVISION,
      KIND_PSALM_TITLE,
      KIND_PSALM_HEADING,
      KIND_VERSE_AFTER_PSALM_HEADING,
      KIND_IMPLICIT_PSALM_OPENING,
      KIND_SPLIT_VERSE_NUMBER,
      KIND_NUMBERED_LINE
    ].freeze

    def self.strict_kind_validation?
      return false if ENV["INAMEN_STRICT_PARSE_EVENT_KINDS"] == "0"
      return true if ENV["INAMEN_STRICT_PARSE_EVENT_KINDS"] == "1"

      ENV["CI"] == "true" || File.basename($PROGRAM_NAME).include?("rspec")
    end

    def self.validate_kind!(kind)
      return unless strict_kind_validation?
      return if KINDS.include?(kind)

      raise ArgumentError,
            "Unknown KjvParseEvent kind: #{kind.inspect} (expected one of: #{KINDS.map(&:inspect).join(", ")})"
    end

    def self.new(**kwargs)
      validate_kind!(kwargs[:kind])
      super
    end
  end
end
