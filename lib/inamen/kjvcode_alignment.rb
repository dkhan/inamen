# frozen_string_literal: true

require_relative "bible_boundary_patterns"

module Inamen
  # Compares near-miss boundary-related counts against kjvcode.com (KJPBS / Cambridge Concord).
  module KjvcodeAlignment
    THE_STAR_KJPBS = BibleBoundaryPatterns::THE_STAR_KJPBS_WORD_COUNTS

    AMEN_NT_KJPBS = 51

    PATTERNS = [
      {
        id: "the_amen_nt_concealed",
        kjvcode: 980,
        label: "The* + Amen (N.T. concealed)",
        run: ->(lines) { BibleBoundaryPatterns.the_amen_nt_concealed(lines) }
      },
      {
        id: "god_pure_nt",
        kjvcode: 1370,
        label: "God* pure (N.T. verse text)",
        run: ->(lines) { { sum: BibleBoundaryPatterns.god_pure_nt(lines) } }
      },
      {
        id: "jesus_boundary_same_verse",
        kjvcode: 2401,
        label: "Jesus + 7-form boundary (same verse, pure)",
        run: ->(lines) { BibleBoundaryPatterns.jesus_boundary_same_verse(lines) }
      },
      {
        id: "jesus_boundary_first7_nt",
        kjvcode: 539,
        label: "Jesus in boundary verses (first 7 N.T., case-sensitive)",
        run: ->(lines) { { sum: BibleBoundaryPatterns.jesus_boundary_first7_nt(lines) } }
      }
    ].freeze

    class << self
      def the_star_nt_breakdown(lines)
        counts = Hash.new(0)
        BibleBoundaryPatterns.send(:each_verse_text_token, lines) do |tok, rec|
          next unless BibleBoundaryPatterns::NT_BOOK_SET.include?(rec[:book])
          next unless BibleBoundaryPatterns.the_star_nt_token?(tok)

          counts[tok] += 1
        end

        THE_STAR_KJPBS.map do |word, target|
          ours = counts[word]
          { word: word, ours: ours, kjvcode: target, diff: ours - target }
        end + counts.reject { |w, _| THE_STAR_KJPBS.key?(w) }.map do |word, ours|
          { word: word, ours: ours, kjvcode: 0, diff: ours, extra: true }
        end
      end

      def report(lines, out: $stdout)
        out.puts "KJV Code alignment (corpus vs kjvcode.com / KJPBS targets)"
        out.puts "Corpus: data/KJV.txt — settled Cambridge Concord may differ on ~28 The* tokens and a few Jesus/God* mentions."
        out.puts

        PATTERNS.each do |entry|
          result = entry[:run].call(lines)
          ours = result[:sum]
          diff = ours - entry[:kjvcode]
          out.puts "#{entry[:label]} (#{entry[:id]})"
          out.puts "  corpus: #{ours}"
          out.puts "  kjvcode: #{entry[:kjvcode]}"
          out.puts "  diff: #{format_diff(diff)}"
          if result.key?(:the_star)
            out.puts "  breakdown: the_star=#{result[:the_star]} amen=#{result[:amen]}"
          elsif result.key?(:boundary)
            out.puts "  breakdown: boundary=#{result[:boundary]} jesus=#{result[:jesus]}"
          end
          out.puts
        end

        out.puts "The* word-level diff (N.T. verse text vs KJPBS reference list):"
        the_star_nt_breakdown(lines).each do |row|
          next if row[:diff].zero?

          label = row[:extra] ? "extra prefix" : ""
          out.puts "  #{row[:word]}: corpus=#{row[:ours]} kjvcode=#{row[:kjvcode]} diff=#{format_diff(row[:diff])} #{label}"
        end
        total_the = 0
        BibleBoundaryPatterns.send(:each_verse_text_token, lines) do |tok, rec|
          total_the += 1 if BibleBoundaryPatterns::NT_BOOK_SET.include?(rec[:book]) &&
                              BibleBoundaryPatterns.the_star_nt_token?(tok)
        end
        out.puts "  The*|THE* prefix total: corpus=#{total_the} kjvcode=929 diff=#{format_diff(total_the - 929)}"
        amen = BibleBoundaryPatterns.the_amen_nt_concealed(lines)[:amen]
        out.puts "  Amen (N.T.): corpus=#{amen} kjvcode=#{AMEN_NT_KJPBS} diff=#{format_diff(amen - AMEN_NT_KJPBS)}"
      end

      private

      def format_diff(n)
        n.positive? ? "+#{n}" : n.to_s
      end
    end
  end
end
