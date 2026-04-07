# frozen_string_literal: true

module Inamen
  # Counts tokens in KJV-style plain text: standalone chapter lines, verse lines
  # that start with a verse number, and everything else as prose.
  class CountingService
    CHAPTER_LINE = /\A\d+\z/
    VERSE_LINE = /\A(\d+)\s+(.+)\z/m

    # Each entry is [category, token_string] with category one of
    # :text_word, :chapter_number, :verse_number.
    def self.labeled_tokens_for_line(line)
      stripped = line.to_s.strip
      return [] if stripped.empty?

      if stripped.match?(CHAPTER_LINE)
        [[:chapter_number, stripped]]
      elsif (m = stripped.match(VERSE_LINE))
        [[:verse_number, m[1]]] + Tokenizer.tokenize(m[2]).map { |t| [:text_word, t] }
      else
        Tokenizer.tokenize(stripped).map { |t| [:text_word, t] }
      end
    end

    def self.counts_for_line(line)
      labels = labeled_tokens_for_line(line)
      {
        text_words: labels.count { |(c, _)| c == :text_word },
        chapter_numbers: labels.count { |(c, _)| c == :chapter_number },
        verse_numbers: labels.count { |(c, _)| c == :verse_number }
      }
    end

    def self.total_for_lines(lines)
      lines.each_with_object(empty_counts) do |line, acc|
        add_counts!(acc, counts_for_line(line))
      end
    end

    def self.combined_total(counts)
      counts[:text_words] + counts[:chapter_numbers] + counts[:verse_numbers]
    end

    def self.empty_counts
      { text_words: 0, chapter_numbers: 0, verse_numbers: 0 }
    end

    def self.add_counts!(acc, partial)
      acc[:text_words] += partial[:text_words]
      acc[:chapter_numbers] += partial[:chapter_numbers]
      acc[:verse_numbers] += partial[:verse_numbers]
      acc
    end
    private_class_method :add_counts!
  end
end
