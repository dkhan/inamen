# frozen_string_literal: true

require "set"

require_relative "feature"

module Inamen
  # Named, reproducible KJV pattern features with documented definitions.
  #
  # Only the two file-stats totals are built in. Every other feature is a
  # user-defined saved feature (see SavedFeature) computed generically through
  # the Discover search pipeline.
  module Features
    CATALOG = [
      FeatureEntry.new(
        id: "combined_total",
        name: "Combined token total (7⁷)",
        description: "Sum of all CountingService buckets on the full KJV file.",
        expected_count: 823_543,
        unit: "tokens",
        scope: "whole_bible",
        notes: "789,629 verse text + 1,034 psalm headings + 186 colophons + 567 other text + 22 psalm 119 divisions + 1,189 chapters + 31,102 verses = 823,543 = 7⁷.",
        kjvcode_url: "https://kjvcode.com/pattern/elton-anomaly/"
      ),
      FeatureEntry.new(
        id: "file_character_total",
        name: "File character total (UTF-8)",
        description: "Every Unicode code point in the edition file as stored on disk—including letters, digits, punctuation, spaces, and newlines.",
        expected_count: 4_233_726,
        unit: "characters",
        scope: "whole_file",
        notes: "4,233,726 = 7 × ⌈777.7 × 777.7⌉. Counts code points, not raw bytes (curly apostrophes U+2019 are one character, three bytes). Inamen discovery."
      )
    ].freeze

    BY_ID = CATALOG.to_h { |entry| [entry.id, entry] }.freeze

    class << self
      def catalog
        CATALOG
      end

      def fetch(id)
        BY_ID.fetch(id.to_s) { raise ArgumentError, "Unknown feature: #{id.inspect}" }
      end

      def run(id, lines:, db: nil, path: nil, edition_id: nil, file_stats: nil)
        entry = fetch(id)
        file_stats ||= FileStatsPublisher.load_for(edition_id, text_path: path) if edition_id && path
        count, details = compute(id, lines, db: db, path: path, file_stats: file_stats)
        FeatureResult.new(
          id: entry.id,
          name: entry.name,
          count: count,
          unit: entry.unit,
          scope: entry.scope,
          description: entry.description,
          notes: entry.notes,
          details: details,
          kjvcode_url: entry.kjvcode_url
        )
      end

      def run_all(lines:, db: nil, path: nil, edition_id: nil)
        file_stats = FileStatsPublisher.load_for(edition_id, text_path: path) if edition_id && path
        CATALOG.map { |entry| run(entry.id, lines: lines, db: db, path: path, edition_id: edition_id, file_stats: file_stats) }
      end

      def print_catalog(out: $stdout)
        headers = %w[id expected unit scope name]
        rows = CATALOG.map do |entry|
          [
            entry.id,
            format_count(entry.expected_count),
            entry.unit,
            entry.scope,
            entry.name
          ]
        end
        print_table(out, headers, rows, align: { "expected" => :right })
      end

      def print_result(result, out: $stdout)
        entry = fetch(result.id)
        ok = result.count == entry.expected_count
        out.puts "Feature: #{result.name} (#{result.id})"
        out.puts "Count: #{result.count} #{result.unit} (#{result.scope})"
        out.puts "Expected: #{entry.expected_count}"
        if entry.kjvcode_expected_count
          kjv_ok = result.count == entry.kjvcode_expected_count
          out.puts "KJV Code target: #{entry.kjvcode_expected_count} (#{kjv_ok ? 'match' : 'diff ' + (result.count - entry.kjvcode_expected_count).to_s})"
        end
        out.puts "Match: #{ok ? 'yes' : 'NO'}"
        out.puts "Definition: #{result.description}"
        out.puts "Notes: #{result.notes}" unless result.notes.to_s.empty?
        result.details&.each { |line| out.puts "  #{line}" }
      end

      private

      def format_count(number)
        number.to_s.reverse.scan(/.{1,3}/).join(",").reverse
      end

      def print_table(out, headers, rows, align: {})
        widths = headers.each_index.map do |i|
          ([headers[i]] + rows.map { |row| row[i].to_s }).map(&:length).max
        end

        write_row = lambda do |cells|
          line = cells.each_with_index.map do |cell, i|
            text = cell.to_s
            align[headers[i]] === :right ? text.rjust(widths[i]) : text.ljust(widths[i])
          end.join("  ")
          out.puts line
        end

        write_row.call(headers)
        write_row.call(widths.map { |w| "-" * w })
        rows.each { |row| write_row.call(row) }
      end

      def compute(id, lines, db:, path:, file_stats: nil)
        case id.to_s
        when "combined_total"
          combined_total(lines, file_stats: file_stats)
        when "file_character_total"
          file_character_total(path, file_stats: file_stats)
        else
          raise ArgumentError, "Unknown feature: #{id.inspect}"
        end
      end

      def combined_total(lines, file_stats: nil)
        if file_stats
          count = file_stats.total
          return [count, ["combined_total=#{count}", "7^7=#{7**7}"]]
        end

        totals = CountingService.total_for_lines(lines)
        count = CountingService.combined_total(totals)
        [count, ["combined_total=#{count}", "7^7=#{7**7}"]]
      end

      def file_character_total(path, file_stats: nil)
        raise ArgumentError, "file_character_total requires path:" if path.to_s.empty?

        if file_stats
          count = file_stats.character_count
          bytes = File.binread(path).bytesize
          seven_factor = 7 * (777.7 * 777.7).ceil
          return [
            count,
            [
              "codepoints=#{count}",
              "bytes=#{bytes}",
              "7*ceil(777.7^2)=#{seven_factor}"
            ]
          ]
        end

        text = File.read(path, encoding: "UTF-8")
        count = text.length
        bytes = File.binread(path).bytesize
        seven_factor = 7 * (777.7 * 777.7).ceil
        [
          count,
          [
            "codepoints=#{count}",
            "bytes=#{bytes}",
            "7*ceil(777.7^2)=#{seven_factor}"
          ]
        ]
      end
    end
  end
end
