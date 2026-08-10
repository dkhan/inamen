# frozen_string_literal: true

require_relative "summary_report"

module Inamen
  # Whole-file token breakdown for the 7^7 (823,543) feature and related discovery scans.
  module FileStatsReport
    Row = Struct.new(:key, :label, :count, keyword_init: true)
    Result = Struct.new(:rows, :total, :character_count, :seven_power, :explorer, keyword_init: true)

    BREAKDOWN = [
      [:verse_text_words, "Words in verse text"],
      [:psalm_heading_words, "Words in psalm headings"],
      [:colophon_words, "Words in colophons"],
      [:psalm_119_words, "Psalm 119 stanza words"],
      [:total_chapters, "Chapter headers"],
      [:total_verses, "Verse numbers"],
      [:psalm_119_inscriptions, "Other divisions (Psalm 119)"],
      [:cover_and_titles, "Words in cover + book titles"]
    ].freeze

    CHARACTER_ROW_KEY = :file_characters
    SEVEN_POWER = 7**7

    class << self
      def build(lines, text_path:, source_lines: nil)
        summary = SummaryReport.build(lines, source_lines: source_lines)
        rows = BREAKDOWN.map do |key, label|
          count =
            if key == :cover_and_titles
              summary[:cover_title_words] + summary[:book_title_words]
            else
              summary.fetch(key)
            end
          Row.new(key: key, label: label, count: count)
        end

        Result.new(
          rows: rows,
          total: rows.sum(&:count),
          character_count: character_count_for(text_path),
          seven_power: SEVEN_POWER
        )
      end

      def character_count_for(text_path)
        return 0 if text_path.to_s.empty? || !File.file?(text_path)

        File.read(text_path, encoding: "UTF-8").length
      end
    end
  end
end
