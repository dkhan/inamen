# frozen_string_literal: true

require "set"

require_relative "feature"

module Inamen
  # Named, reproducible KJV pattern features with documented definitions.
  module Features
    JESUS_NON_CHRIST_VERSES = [
      ["Acts", 7, 45],       # Joshua (KJV)
      ["Hebrews", 4, 8],     # Joshua (KJV)
      ["Colossians", 4, 11]  # Jesus called Justus
    ].freeze

    CATALOG = [
      FeatureEntry.new(
        id: "combined_total",
        name: "Combined token total (7⁷)",
        description: "Sum of all CountingService buckets on the full KJV file.",
        expected_count: 823_543,
        unit: "tokens",
        scope: "whole_bible",
        notes: "789,629 verse text + 1,034 psalm headings + 186 colophons + 567 other text + 22 psalm 119 divisions + 1,189 chapters + 31,102 verses = 823,543 = 7⁷."
      ),
      FeatureEntry.new(
        id: "peter_verses",
        name: "Verses mentioning Peter",
        description: "Distinct verses whose body text contains token Peter (case-insensitive exact match).",
        expected_count: 153,
        unit: "verses",
        scope: "whole_bible",
        notes: "Verse text only. Does not count Simon without the token Peter."
      ),
      FeatureEntry.new(
        id: "paul_verses",
        name: "Verses mentioning Paul",
        description: "Distinct verses whose body text contains token Paul (case-insensitive exact match).",
        expected_count: 153,
        unit: "verses",
        scope: "whole_bible",
        notes: "Verse text only. Does not include Saul."
      ),
      FeatureEntry.new(
        id: "fishermen_gospels",
        name: "John 21 fishing party (Gospels)",
        description: "Occurrences of Peter*, Thomas*, Nathanael* in Gospels verse text; James/John son-of-Zebedee whitelists only.",
        expected_count: 153,
        unit: "occurrences",
        scope: "gospels",
        notes: "See FishermenNameCounts. Sum of five names in Matthew–John."
      ),
      FeatureEntry.new(
        id: "jesus_mentions",
        name: "Jesus / JESUS mentions (Christ)",
        description: "Token occurrences Jesus or JESUS in verse text, psalm superscriptions, and colophons; excluding Joshua (Acts 7:45, Hebrews 4:8) and Jesus Justus (Colossians 4:11).",
        expected_count: 980,
        unit: "occurrences",
        scope: "scannable",
        notes: "980 = 7×70 + 7×70. Raw scannable Jesus+JESUS count is 983; three non-Christ verses excluded."
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

      def run(id, lines:, db: nil)
        entry = fetch(id)
        count, details = compute(id, lines, db: db)
        FeatureResult.new(
          id: entry.id,
          name: entry.name,
          count: count,
          unit: entry.unit,
          scope: entry.scope,
          description: entry.description,
          notes: entry.notes,
          details: details
        )
      end

      def run_all(lines:, db: nil)
        CATALOG.map { |entry| run(entry.id, lines: lines, db: db) }
      end

      def print_catalog(out: $stdout)
        out.puts "id\texpected\tunit\tscope\tname"
        CATALOG.each do |entry|
          out.puts "#{entry.id}\t#{entry.expected_count}\t#{entry.unit}\t#{entry.scope}\t#{entry.name}"
        end
      end

      def print_result(result, out: $stdout)
        entry = fetch(result.id)
        ok = result.count == entry.expected_count
        out.puts "Feature: #{result.name} (#{result.id})"
        out.puts "Count: #{result.count} #{result.unit} (#{result.scope})"
        out.puts "Expected: #{entry.expected_count}"
        out.puts "Match: #{ok ? 'yes' : 'NO'}"
        out.puts "Definition: #{result.description}"
        out.puts "Notes: #{result.notes}" unless result.notes.to_s.empty?
        result.details&.each { |line| out.puts "  #{line}" }
      end

      private

      def compute(id, lines, db:)
        case id.to_s
        when "combined_total"
          combined_total(lines)
        when "peter_verses"
          name_verse_count(lines, /\APeter\z/i)
        when "paul_verses"
          name_verse_count(lines, /\APaul\z/i)
        when "fishermen_gospels"
          fishermen_gospels(lines)
        when "jesus_mentions"
          jesus_mentions(lines, db: db)
        else
          raise ArgumentError, "Unknown feature: #{id.inspect}"
        end
      end

      def combined_total(lines)
        totals = CountingService.total_for_lines(lines)
        count = CountingService.combined_total(totals)
        [count, ["combined_total=#{count}", "7^7=#{7**7}"]]
      end

      def name_verse_count(lines, token_re)
        verses = Set.new
        VerseIndex.each_verse(lines) do |book, chapter, verse, text|
          next unless Tokenizer.tokenize(text).any? { |tok| tok.match?(token_re) }

          verses << [book, chapter, verse]
        end
        [verses.size, ["distinct_verses=#{verses.size}"]]
      end

      def fishermen_gospels(lines)
        counts = FishermenNameCounts.counts(lines, scope: :gospels)
        [counts[:sum], counts.map { |k, v| "#{k}=#{v}" }]
      end

      def jesus_mentions(lines, db:)
        excluded = JESUS_NON_CHRIST_VERSES.to_set
        if db
          rows = db.execute(<<~SQL)
            SELECT book, chapter, verse FROM tokens
            WHERE bucket IN ('verse_text', 'psalm_heading', 'colophon')
              AND token_raw IN ('Jesus', 'JESUS')
          SQL
          raw = rows.size
          count = rows.count { |book, chapter, verse| !excluded.include?([book, chapter, verse]) }
        else
          require_relative "corpus_indexer"
          require_relative "corpus_store"
          raw = 0
          count = 0
          CorpusIndexer.each_token_record(lines) do |rec|
            next unless CorpusStore::SCAN_BUCKETS.include?(rec[:bucket])
            next unless rec[:token_raw] == "Jesus" || rec[:token_raw] == "JESUS"

            raw += 1
            count += 1 unless excluded.include?([rec[:book], rec[:chapter], rec[:verse]])
          end
        end

        excluded_n = raw - count
        [count, ["raw_scannable=#{raw}", "excluded=#{excluded_n}", "verses_excluded=#{JESUS_NON_CHRIST_VERSES.length}"]]
      end
    end
  end
end
