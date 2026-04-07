# frozen_string_literal: true

module Inamen
  # Lines that add to +text_words+ in CountingService.total_for_lines (same state machine).
  module TextWordsDebugReport
    GROUP_LABELS = {
      book_titles_cover: "book titles / cover",
      colophon: "colophons",
      other: "other"
    }.freeze

    def self.bucket_for(classification)
      case classification
      when :book_title then :book_titles_cover
      when :colophon then :colophon
      else :other
      end
    end

    # Builds entries and per-bucket token sums (+total+).
    def self.collect(lines)
      entries = []
      buckets = Hash.new(0)
      total = 0

      KjvLineParser.each_step(lines) do |step|
        next unless step.text_words_debug

        d = step.text_words_debug
        classification = d[:classification]
        tok = d[:tokens]
        total += tok
        buckets[bucket_for(classification)] += tok

        entries << {
          lineno: d[:lineno],
          raw: d[:raw],
          tokens: tok,
          classification: classification
        }
      end

      [entries, buckets, total]
    end

    def self.print_report(lines, out: $stdout)
      entries, buckets, total = collect(lines)

      out.puts "Lines contributing to text_words (#{entries.size} lines, #{total} tokens)"
      out.puts

      entries.each do |e|
        out.puts "L#{e[:lineno]}\t#{e[:tokens]} tok\t#{e[:classification]}"
        out.puts "  #{e[:raw]}"
        out.puts
      end

      out.puts "--- Subtotals (by LineClassifier bucket) ---"
      %i[book_titles_cover colophon other].each do |key|
        t = buckets[key]
        label = GROUP_LABELS[key]
        out.puts "#{label}: #{t} tokens"
      end

      other_detail = entries
        .select { |e| bucket_for(e[:classification]) == :other }
        .group_by { |e| e[:classification] }
        .transform_values { |arr| arr.sum { |x| x[:tokens] } }
        .sort_by { |(k, _)| k.to_s }

      unless other_detail.empty?
        out.puts
        out.puts "--- other (by classification) ---"
        other_detail.each do |klass, tok|
          out.puts "  #{klass}: #{tok} tokens"
        end
      end

      out.puts
      out.puts "Total text_words: #{total}"
    end
  end
end
