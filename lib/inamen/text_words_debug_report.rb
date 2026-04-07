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

      expecting_implicit_psalm_verse_1 = false
      expecting_split_verse_body = false
      prev_nonempty_stripped = nil

      lines.each_with_index do |line, i|
        s = line.to_s.strip
        next if s.empty?

        if expecting_split_verse_body
          expecting_split_verse_body = false
          prev_nonempty_stripped = s
          next
        end

        if PsalmHeading.stanza_label?(s)
          expecting_implicit_psalm_verse_1 = true
          prev_nonempty_stripped = s
          next
        end

        if s.match?(CountingService::PSALM_TITLE)
          expecting_implicit_psalm_verse_1 = true
          prev_nonempty_stripped = s
          next
        end

        if expecting_implicit_psalm_verse_1
          if PsalmHeading.match?(s)
            prev_nonempty_stripped = s
            next
          end
          if s.match?(CountingService::VERSE_LINE)
            expecting_implicit_psalm_verse_1 = false
            prev_nonempty_stripped = s
            next
          end
          r = CountingService.implicit_psalm_unnumbered_resolution(lines, i, s)
          expecting_implicit_psalm_verse_1 = false if r[:clear_waiting]
          prev_nonempty_stripped = s
          next
        end

        ch = CountingService::CHAPTER_LINE
        if prev_nonempty_stripped&.match?(ch) && s.match?(ch)
          expecting_split_verse_body = true
          prev_nonempty_stripped = s
          next
        end

        partial = CountingService.counts_for_line(s)
        prev_nonempty_stripped = s

        next if partial[:text_words].zero?

        classification = LineClassifier.classify(line)
        tok = partial[:text_words]
        total += tok
        buckets[bucket_for(classification)] += tok

        entries << {
          lineno: i + 1,
          raw: line.to_s.chomp,
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
