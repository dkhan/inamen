# frozen_string_literal: true

require "set"

require_relative "feature"
require_relative "bible_boundary_patterns"

module Inamen
  # Named, reproducible KJV pattern features with documented definitions.
  module Features
    JESUS_NON_CHRIST_VERSES = BibleBoundaryPatterns::JESUS_NON_CHRIST_VERSES

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
      ),
      FeatureEntry.new(
        id: "bible_boundary_words",
        name: "Bible boundary words (Alpha & Omega)",
        description: "Sum of scannable occurrences: In (ci), earth (cs), The (ci), Amen (cs)—anchored on first/last tokens of Genesis 1:1 and Revelation 22:21.",
        expected_count: 77_777,
        unit: "occurrences",
        scope: "scannable",
        notes: "Genesis 1:1: IN…earth. Revelation 22:21: The…Amen. Counts: in=12,674 + earth=985 + the=64,041 + amen=77 = 77,777."
      ),
      FeatureEntry.new(
        id: "amen_77",
        name: "Amen 77× (last word of the Bible)",
        description: "Case-sensitive Amen token occurrences in scannable text.",
        expected_count: 77,
        unit: "occurrences",
        scope: "scannable",
        notes: "Revelation 22:21 ends with Amen. Case-insensitive count is 78 (Numbers 5:22 has amen)."
      ),
      FeatureEntry.new(
        id: "boundary_anchor_verses",
        name: "Boundary words in anchor verses",
        description: "In/earth/The/Amen mentions in Genesis 1:1 and Revelation 22:21 only (5 + 2 = 7).",
        expected_count: 7,
        unit: "occurrences",
        scope: "verse_text",
        notes: "Genesis 1:1 has five boundary tokens; Revelation 22:21 has two."
      ),
      FeatureEntry.new(
        id: "boundary_seven_forms",
        name: "Seven case-sensitive boundary forms",
        description: "Scannable counts of In+IN, in, earth, The, the, THE, Amen—the seven partitions of the 77,777 sum.",
        expected_count: 77_777,
        unit: "occurrences",
        scope: "scannable",
        notes: "In+IN=336 + in=12,338 + earth=985 + The=1,762 + the=62,173 + THE=106 + Amen=77 = 77,777."
      ),
      FeatureEntry.new(
        id: "in_amen_genesis_revelation",
        name: "In + Amen in Genesis & Revelation",
        description: "Scannable In (ci) and Amen (cs) occurrences in the first and last books only.",
        expected_count: 777,
        unit: "occurrences",
        scope: "genesis_revelation",
        notes: "Sister pattern to the 77,777 boundary sum; 777 = 7×111."
      ),
      FeatureEntry.new(
        id: "the_amen_nt_concealed",
        name: "The* + Amen in the N.T. (concealed)",
        description: "N.T. verse text: The* (\\AThe) | THE* (\\ATHE) + Amen* (\\AAmen) | AMEN* (\\AAMEN), case-sensitive.",
        expected_count: 980,
        kjvcode_expected_count: 980,
        unit: "occurrences",
        scope: "new_testament",
        notes: "Concealed capitals: Then, Therefore, etc. KJPBS/Cambridge: 929+51=980."
      ),
      FeatureEntry.new(
        id: "god_jesus_genesis_revelation",
        name: "God + Jesus in Genesis & Revelation",
        description: "Scannable God (ci) and Jesus/JESUS occurrences in Genesis and Revelation.",
        expected_count: 343,
        unit: "occurrences",
        scope: "genesis_revelation",
        notes: "343 = 7×7×7. God=329 + Jesus=14 in first and last books."
      ),
      FeatureEntry.new(
        id: "first_last_chapter_words",
        name: "First & last chapter word count",
        description: "Total verse-text tokens in Genesis 1 and Revelation 22.",
        expected_count: 1370,
        unit: "tokens",
        scope: "verse_text",
        notes: "Genesis 1=797 + Revelation 22=573 = 1,370. KJV Code pairs this with God* pure NT count."
      ),
      FeatureEntry.new(
        id: "ot_first_last_chapter_words",
        name: "O.T. first & last chapter word count",
        description: "Total verse-text tokens in Genesis 1 and Malachi 4.",
        expected_count: 980,
        unit: "tokens",
        scope: "old_testament",
        notes: "Genesis 1=797 + Malachi 4=183 = 980. Matches pure Jesus N.T. mention count."
      ),
      FeatureEntry.new(
        id: "god_pure_nt",
        name: "God* pure mentions in the N.T.",
        description: "Verse-text capitalized God forms: God, God's, Gods, Godhead, God-ward in New Testament books.",
        expected_count: 1370,
        kjvcode_expected_count: 1370,
        unit: "occurrences",
        scope: "new_testament",
        notes: "Verse text: God, God\u2019s, Gods, Godhead, God-ward in N.T. Pairs with 1,370-word Gen 1 + Rev 22 count."
      ),
      FeatureEntry.new(
        id: "beginning_end_amen",
        name: "Beginning + End + Amen",
        description: "Scannable case-insensitive beginning and end tokens plus case-sensitive Amen.",
        expected_count: 490,
        unit: "occurrences",
        scope: "scannable",
        notes: "490 = 70×7. Alpha/Omega titles from Revelation 22:13."
      ),
      FeatureEntry.new(
        id: "jesus_boundary_same_verse",
        name: "Jesus + boundary forms in same verse",
        description: "In verses containing both Jesus (cs) and a seven-form boundary token, sum all such tokens.",
        expected_count: 2401,
        kjvcode_expected_count: 2401,
        unit: "occurrences",
        scope: "verse_text",
        notes: "Verses with boundary forms + pure Jesus (cs, excl. Jesus'); antimention verses excluded. KJPBS: 1,658+743=7\u2074."
      ),
      FeatureEntry.new(
        id: "jesus_boundary_first7_nt",
        name: "Jesus in boundary verses (first 7 N.T. books)",
        description: "Jesus (cs) occurrences in scannable verses that also contain a seven-form boundary token, Matthew–1 Corinthians.",
        expected_count: 539,
        kjvcode_expected_count: 539,
        unit: "occurrences",
        scope: "first_7_nt",
        notes: "Jesus (cs) in verse-text verses with a 7-form boundary token, Matthew\u20131 Corinthians. KJPBS: 77\u00d77."
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
        when "bible_boundary_words"
          bible_boundary_words(lines, db: db)
        when "amen_77"
          amen_77(lines, db: db)
        when "boundary_anchor_verses"
          boundary_anchor_verses(lines)
        when "boundary_seven_forms"
          boundary_seven_forms(lines, db: db)
        when "in_amen_genesis_revelation"
          in_amen_genesis_revelation(lines, db: db)
        when "the_amen_nt_concealed"
          the_amen_nt_concealed(lines)
        when "god_jesus_genesis_revelation"
          god_jesus_genesis_revelation(lines, db: db)
        when "first_last_chapter_words"
          first_last_chapter_words(lines)
        when "ot_first_last_chapter_words"
          ot_first_last_chapter_words(lines)
        when "god_pure_nt"
          god_pure_nt(lines)
        when "beginning_end_amen"
          beginning_end_amen(lines, db: db)
        when "jesus_boundary_same_verse"
          jesus_boundary_same_verse(lines, db: db)
        when "jesus_boundary_first7_nt"
          jesus_boundary_first7_nt(lines, db: db)
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

      def bible_boundary_words(lines, db:)
        counts = BibleBoundaryWords.counts(lines, db: db)
        details = BibleBoundaryWords::RULES.map do |rule|
          "#{rule[:key]}=#{counts[rule[:key]]} (#{rule[:anchor]})"
        end
        [counts[:sum], details]
      end

      def amen_77(lines, db:)
        count = BibleBoundaryPatterns.amen_count(lines, db: db)
        [count, ["amen=#{count}"]]
      end

      def boundary_anchor_verses(lines)
        count = BibleBoundaryPatterns.anchor_verse_mentions(lines)
        [count, ["genesis_1_1 + revelation_22_21=#{count}"]]
      end

      def boundary_seven_forms(lines, db:)
        counts = BibleBoundaryPatterns.seven_form_counts(lines, db: db)
        details = BibleBoundaryPatterns::SEVEN_FORMS.map do |form|
          "#{form[:key]}=#{counts[form[:key]]} (#{form[:label]})"
        end
        [counts[:sum], details]
      end

      def in_amen_genesis_revelation(lines, db:)
        count = BibleBoundaryPatterns.in_amen_genesis_revelation(lines, db: db)
        [count, ["in_amen_gen_rev=#{count}"]]
      end

      def the_amen_nt_concealed(lines)
        counts = BibleBoundaryPatterns.the_amen_nt_concealed(lines)
        [counts[:sum], ["the_star=#{counts[:the_star]}", "amen=#{counts[:amen]}"]]
      end

      def god_jesus_genesis_revelation(lines, db:)
        counts = BibleBoundaryPatterns.god_jesus_genesis_revelation(lines, db: db)
        [counts[:sum], ["god=#{counts[:god]}", "jesus=#{counts[:jesus]}"]]
      end

      def first_last_chapter_words(lines)
        counts = BibleBoundaryPatterns.first_last_chapter_word_count(lines)
        [counts[:sum], ["genesis_1=#{counts[:genesis]}", "revelation_22=#{counts[:revelation]}"]]
      end

      def ot_first_last_chapter_words(lines)
        counts = BibleBoundaryPatterns.ot_first_last_chapter_word_count(lines)
        [counts[:sum], ["genesis_1=#{counts[:genesis]}", "malachi_4=#{counts[:malachi]}"]]
      end

      def god_pure_nt(lines)
        count = BibleBoundaryPatterns.god_pure_nt(lines)
        [count, ["god_pure_nt=#{count}"]]
      end

      def beginning_end_amen(lines, db:)
        counts = BibleBoundaryPatterns.beginning_end_amen(lines, db: db)
        [counts[:sum], ["beginning=#{counts[:beginning]}", "end=#{counts[:end]}", "amen=#{counts[:amen]}"]]
      end

      def jesus_boundary_same_verse(lines, db:)
        counts = BibleBoundaryPatterns.jesus_boundary_same_verse(lines, db: db)
        [counts[:sum], ["boundary=#{counts[:boundary]}", "jesus=#{counts[:jesus]}"]]
      end

      def jesus_boundary_first7_nt(lines, db:)
        count = BibleBoundaryPatterns.jesus_boundary_first7_nt(lines, db: db)
        [count, ["jesus_in_boundary_verses=#{count}"]]
      end
    end
  end
end
