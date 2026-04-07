# frozen_string_literal: true

module Inamen
  # Lines that add to +psalm_heading_words+ in CountingService.total_for_lines (same state machine).
  module PsalmHeadingWordsDebugReport
    def self.collect(lines)
      entries = []
      total = 0

      KjvLineParser.each_step(lines) do |step|
        next unless step.psalm_heading_debug

        d = step.psalm_heading_debug
        tok = d[:tokens]
        total += tok
        entries << { lineno: d[:lineno], raw: d[:raw], tokens: tok }
      end

      [entries, total]
    end

    def self.print_report(lines, out: $stdout)
      entries, total = collect(lines)

      out.puts "Lines contributing to psalm_heading_words (#{entries.size} lines)"
      out.puts

      entries.each do |e|
        out.puts "L#{e[:lineno]}\t#{e[:tokens]} tok"
        out.puts "  #{e[:raw]}"
        out.puts
      end

      out.puts "Total psalm_heading_words: #{total}"
    end
  end
end
