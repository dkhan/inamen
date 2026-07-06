# frozen_string_literal: true

require "set"

require_relative "feature"
require_relative "bible_boundary_patterns"

module Inamen
  # Named, reproducible KJV pattern features with documented definitions.
  module Features
    JESUS_POSSESSIVE = "Jesus\u2019"
    JESUS_NON_CHRIST_VERSES = BibleBoundaryPatterns::JESUS_NON_CHRIST_VERSES

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
      ),
      FeatureEntry.new(
        id: "peter_verses",
        name: "Verses mentioning Peter",
        description: "Distinct verses whose body text contains token Peter (case-insensitive exact match).",
        expected_count: 153,
        unit: "verses",
        scope: "whole_bible",
        notes: "Verse text only. Does not count Simon without the token Peter.",
        kjvcode_url: "https://kjvcode.com/pattern/peter-fisher-of-the-jews-153v/"
      ),
      FeatureEntry.new(
        id: "paul_verses",
        name: "Verses mentioning Paul",
        description: "Distinct verses whose body text contains token Paul (case-insensitive exact match).",
        expected_count: 153,
        unit: "verses",
        scope: "whole_bible",
        notes: "Verse text only. Does not include Saul.",
        kjvcode_url: "https://kjvcode.com/pattern/paul-fisher-of-the-gentiles-153v/"
      ),
      FeatureEntry.new(
        id: "fishermen_gospels",
        name: "John 21 fishing party (Gospels)",
        description: "Occurrences of Peter*, Thomas*, Nathanael* in Gospels verse text; James/John son-of-Zebedee whitelists only.",
        expected_count: 153,
        unit: "occurrences",
        scope: "gospels",
        notes: "See FishermenNameCounts. Sum of five names in Matthew–John.",
        kjvcode_url: "https://kjvcode.com/pattern/men-who-caught-153-fishes-153x-in-gospels/"
      ),
      FeatureEntry.new(
        id: "jesus_mentions",
        name: "Jesus / JESUS mentions (Christ)",
        description: "Token occurrences Jesus or JESUS in verse text, psalm superscriptions, and colophons; excluding Joshua (Acts 7:45, Hebrews 4:8) and Jesus Justus (Colossians 4:11).",
        expected_count: 980,
        unit: "occurrences",
        scope: "scannable",
        notes: "980 = 7×70 + 7×70. Raw scannable Jesus+JESUS count is 983; three non-Christ verses excluded.",
        kjvcode_url: "https://kjvcode.com/pattern/jesus-70x7/?logic=total-mentions"
      ),
      FeatureEntry.new(
        id: "bible_boundary_words",
        name: "Bible boundary words (Alpha & Omega)",
        description: "Sum of scannable occurrences: In (ci), earth (cs), The (ci), Amen (cs)—anchored on first/last tokens of Genesis 1:1 and Revelation 22:21.",
        expected_count: 77_777,
        unit: "occurrences",
        scope: "scannable",
        notes: "Genesis 1:1: IN…earth. Revelation 22:21: The…Amen. Counts: in=12,674 + earth=985 + the=64,041 + amen=77 = 77,777.",
        kjvcode_url: "https://kjvcode.com/pattern/first-last-words-first-last-verses-77777x/"
      ),
      FeatureEntry.new(
        id: "amen_77",
        name: "Amen 77× (last word of the Bible)",
        description: "Case-sensitive Amen token occurrences in scannable text.",
        expected_count: 77,
        unit: "occurrences",
        scope: "scannable",
        notes: "Revelation 22:21 ends with Amen. Case-insensitive count is 78 (Numbers 5:22 has amen).",
        kjvcode_url: "https://kjvcode.com/pattern/amen-77x-last-word-of-bible/"
      ),
      FeatureEntry.new(
        id: "boundary_anchor_verses",
        name: "Boundary words in anchor verses",
        description: "In/earth/The/Amen mentions in Genesis 1:1 and Revelation 22:21 only (5 + 2 = 7).",
        expected_count: 7,
        unit: "occurrences",
        scope: "verse_text",
        notes: "Genesis 1:1 has five boundary tokens; Revelation 22:21 has two.",
        kjvcode_url: "https://kjvcode.com/pattern/first-last-words-first-last-verses-77777x/"
      ),
      FeatureEntry.new(
        id: "boundary_seven_forms",
        name: "Seven case-sensitive boundary forms",
        description: "Scannable counts of In+IN, in, earth, The, the, THE, Amen—the seven partitions of the 77,777 sum.",
        expected_count: 77_777,
        unit: "occurrences",
        scope: "scannable",
        notes: "In+IN=336 + in=12,338 + earth=985 + The=1,762 + the=62,173 + THE=106 + Amen=77 = 77,777.",
        kjvcode_url: "https://kjvcode.com/pattern/first-last-words-first-last-verses-77777x/"
      ),
      FeatureEntry.new(
        id: "in_amen_genesis_revelation",
        name: "In + Amen in Genesis & Revelation",
        description: "Scannable In (ci) and Amen (cs) occurrences in the first and last books only.",
        expected_count: 777,
        unit: "occurrences",
        scope: "genesis_revelation",
        notes: "Sister pattern to the 77,777 boundary sum; 777 = 7×111.",
        kjvcode_url: "https://kjvcode.com/pattern/777x-first-and-last-words-of-the-bible/"
      ),
      FeatureEntry.new(
        id: "the_amen_nt_concealed",
        name: "The* + Amen in the N.T. (concealed)",
        description: "N.T. verse text: The* (\\AThe) | THE* (\\ATHE) + Amen* (\\AAmen) | AMEN* (\\AAMEN), case-sensitive.",
        expected_count: 980,
        kjvcode_expected_count: 980,
        unit: "occurrences",
        scope: "new_testament",
        notes: "Concealed capitals: Then, Therefore, etc. KJPBS/Cambridge: 929+51=980.",
        kjvcode_url: "https://kjvcode.com/pattern/first-and-last-words-nt-980x/"
      ),
      FeatureEntry.new(
        id: "god_jesus_genesis_revelation",
        name: "God + Jesus in Genesis & Revelation",
        description: "Scannable God (ci) and Jesus/JESUS occurrences in Genesis and Revelation.",
        expected_count: 343,
        unit: "occurrences",
        scope: "genesis_revelation",
        notes: "343 = 7×7×7. God=329 + Jesus=14 in first and last books.",
        kjvcode_url: "https://kjvcode.com/pattern/7x7x7-god-jesus/"
      ),
      FeatureEntry.new(
        id: "first_last_chapter_words",
        name: "First & last chapter word count",
        description: "Total verse-text tokens in Genesis 1 and Revelation 22.",
        expected_count: 1370,
        unit: "tokens",
        scope: "verse_text",
        notes: "Genesis 1=797 + Revelation 22=573 = 1,370. KJV Code pairs this with God* pure NT count.",
        kjvcode_url: "https://kjvcode.com/pattern/first-last-chapters-1370-god-1370/"
      ),
      FeatureEntry.new(
        id: "ot_first_last_chapter_words",
        name: "O.T. first & last chapter word count",
        description: "Total verse-text tokens in Genesis 1 and Malachi 4.",
        expected_count: 980,
        unit: "tokens",
        scope: "old_testament",
        notes: "Genesis 1=797 + Malachi 4=183 = 980. Matches pure Jesus N.T. mention count.",
        kjvcode_url: "https://kjvcode.com/pattern/first-last-chapters-ot-980-words-jesus-980x/"
      ),
      FeatureEntry.new(
        id: "god_pure_nt",
        name: "God* pure mentions in the N.T.",
        description: "Verse-text capitalized God forms: God, God's, Gods, Godhead, God-ward in New Testament books.",
        expected_count: 1370,
        kjvcode_expected_count: 1370,
        unit: "occurrences",
        scope: "new_testament",
        notes: "Verse text: God, God\u2019s, Gods, Godhead, God-ward in N.T. Pairs with 1,370-word Gen 1 + Rev 22 count.",
        kjvcode_url: "https://kjvcode.com/pattern/first-last-chapters-1370-god-1370/"
      ),
      FeatureEntry.new(
        id: "beginning_end_amen",
        name: "Beginning + End + Amen",
        description: "Scannable case-insensitive beginning and end tokens plus case-sensitive Amen.",
        expected_count: 490,
        unit: "occurrences",
        scope: "scannable",
        notes: "490 = 70×7. Alpha/Omega titles from Revelation 22:13.",
        kjvcode_url: "https://kjvcode.com/pattern/beginning-end-amen-70x7-in-the-bible/"
      ),
      FeatureEntry.new(
        id: "jesus_boundary_same_verse",
        name: "Jesus + boundary forms in same verse",
        description: "In verses containing both Jesus (cs) and a seven-form boundary token, sum all such tokens.",
        expected_count: 2401,
        kjvcode_expected_count: 2401,
        unit: "occurrences",
        scope: "verse_text",
        notes: "Verses with boundary forms + pure Jesus (cs, excl. Jesus'); antimention verses excluded. KJPBS: 1,658+743=7\u2074.",
        kjvcode_url: "https://kjvcode.com/pattern/first-last-words-of-first-last-verses-jesus-7x7x7x7-same-verse/"
      ),
      FeatureEntry.new(
        id: "jesus_boundary_first7_nt",
        name: "Jesus in boundary verses (first 7 N.T. books)",
        description: "Jesus (cs) occurrences in scannable verses that also contain a seven-form boundary token, Matthew–1 Corinthians.",
        expected_count: 539,
        kjvcode_expected_count: 539,
        unit: "occurrences",
        scope: "first_7_nt",
        notes: "Jesus (cs) in verse-text verses with a 7-form boundary token, Matthew\u20131 Corinthians. KJPBS: 77\u00d77.",
        kjvcode_url: "https://kjvcode.com/pattern/jesus-77x7-same-v-77777x-anomaly-first-7-books/"
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

      def run(id, lines:, db: nil, path: nil)
        entry = fetch(id)
        count, details = compute(id, lines, db: db, path: path)
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

      def run_all(lines:, db: nil, path: nil)
        VerseIndex.verse_map(lines)
        CATALOG.map { |entry| run(entry.id, lines: lines, db: db, path: path) }
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

      def compute(id, lines, db:, path:)
        case id.to_s
        when "combined_total"
          combined_total(lines)
        when "file_character_total"
          file_character_total(path)
        when "peter_verses"
          name_verse_count(lines, :peter)
        when "paul_verses"
          name_verse_count(lines, :paul)
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

      def file_character_total(path)
        raise ArgumentError, "file_character_total requires path:" if path.to_s.empty?

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

      def name_verse_count(lines, which)
        count = distinct_name_verse_counts(lines).fetch(which)
        [count, ["distinct_verses=#{count}"]]
      end

      def distinct_name_verse_counts(lines)
        @name_verse_counts_cache ||= {}
        @name_verse_counts_cache[lines.__id__] ||= compute_distinct_name_verse_counts(lines)
      end

      def compute_distinct_name_verse_counts(lines)
        peter = 0
        paul = 0
        VerseIndex.each_verse(lines) do |book, chapter, verse, text|
          toks = Tokenizer.tokenize(text)
          peter += 1 if toks.any? { |t| t.match?(/\APeter\z/i) }
          paul += 1 if toks.any? { |t| t.match?(/\APaul\z/i) }
        end
        { peter: peter, paul: paul }
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
              AND token_raw IN ('Jesus', 'JESUS', '#{JESUS_POSSESSIVE}')
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
            next unless %w[Jesus JESUS].include?(rec[:token_raw]) || rec[:token_raw] == JESUS_POSSESSIVE

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
