# frozen_string_literal: true

require "set"

require_relative "tokenizer"
require_relative "book_stats_report"
require_relative "verse_index"
require_relative "corpus_store"

module Inamen
  # Patterns anchored on the first/last words of Genesis 1:1 and Revelation 22:21,
  # and related "Alpha and Omega" features from kjvcode.com.
  module BibleBoundaryPatterns
    GENESIS = { book: "Genesis", chapter: 1, verse: 1 }.freeze
    REVELATION = { book: "Revelation", chapter: 22, verse: 21 }.freeze

    GEN_REV = %w[Genesis Revelation].freeze

    # Four-word boundary sum (In ci, earth cs, The ci, Amen cs) → 77,777.
    BOUNDARY_RULES = [
      { key: :in, label: "In", case: :insensitive, anchor: "Genesis 1:1 first word",
        match: /\AIn\z/i },
      { key: :earth, label: "earth", case: :sensitive, anchor: "Genesis 1:1 last word",
        match: /\Aearth\z/ },
      { key: :the, label: "The", case: :insensitive, anchor: "Revelation 22:21 first word",
        match: /\AThe\z/i },
      { key: :amen, label: "Amen", case: :sensitive, anchor: "Revelation 22:21 last word",
        match: /\AAmen\z/ }
    ].freeze

    # Seven case-sensitive partitions that also sum to 77,777 (In includes IN).
    SEVEN_FORMS = [
      { key: :in_cap, label: "In+IN", tokens: %w[In IN] },
      { key: :in_lower, label: "in", tokens: %w[in] },
      { key: :earth, label: "earth", tokens: %w[earth] },
      { key: :the_cap, label: "The", tokens: %w[The] },
      { key: :the_lower, label: "the", tokens: %w[the] },
      { key: :the_upper, label: "THE", tokens: %w[THE] },
      { key: :amen, label: "Amen", tokens: %w[Amen] }
    ].freeze

    SEVEN_FORM_TOKEN_SET = SEVEN_FORMS.flat_map { |f| f[:tokens] }.to_set.freeze

    # Verses where token Jesus refers to Joshua or Jesus Justus (kjvcode pure Jesus).
    JESUS_NON_CHRIST_VERSES = [
      ["Acts", 7, 45],
      ["Hebrews", 4, 8],
      ["Colossians", 4, 11]
    ].freeze
    JESUS_NON_CHRIST_VERSE_SET = JESUS_NON_CHRIST_VERSES.to_set.freeze

    # Concealed first/last words of the N.T. (kjvcode first-and-last-words-nt-980x):
    # The* (/\AThe/) | THE* (/\ATHE/) and Amen* (/\AAmen/) | AMEN* (/\AAMEN/), case-sensitive.
    THE_STAR_PREFIX = /\AThe/
    THE_UPPER_STAR_PREFIX = /\ATHE/
    AMEN_STAR_PREFIX = /\AAmen/
    AMEN_UPPER_STAR_PREFIX = /\AAMEN/

    # Reference breakdown from kjvcode.com (929 + 51 = 980 on Cambridge Concord).
    THE_STAR_KJPBS_WORD_COUNTS = {
      "The" => 266, "THE" => 12, "Then" => 352, "Therefore" => 85, "There" => 59,
      "Therewith" => 1, "They" => 78, "Them" => 2, "These" => 59, "Their" => 2,
      "Theophilus" => 2, "Thefts" => 1, "Theudas" => 1, "Thessalonians" => 3,
      "Thessalonica" => 6
    }.freeze

    GOD_PURE_PATTERNS = [
      /\AGod\z/,
      /\AGod['\u{2019}]s\z/,
      /\AGods\z/,
      /\AGodhead\z/,
      /\AGod-ward\z/
    ].freeze

    NT_BOOKS = BookStatsReport::CANON.drop(39).map(&:first).freeze
    OT_BOOKS = BookStatsReport::CANON.first(39).map(&:first).freeze
    FIRST_7_NT = NT_BOOKS.first(7).freeze
    NT_BOOK_SET = NT_BOOKS.to_set.freeze
    GEN_REV_SET = GEN_REV.to_set.freeze
    FIRST_7_NT_SET = FIRST_7_NT.to_set.freeze

    class << self
      def anchor_tokens(lines)
        gen = VerseIndex.verse_text(lines, **GENESIS)
        rev = VerseIndex.verse_text(lines, **REVELATION)
        gen_toks = Tokenizer.tokenize(gen.to_s)
        rev_toks = Tokenizer.tokenize(rev.to_s)
        {
          genesis_first: gen_toks.first,
          genesis_last: gen_toks.last,
          revelation_first: rev_toks.first,
          revelation_last: rev_toks.last
        }
      end

      def boundary_word_counts(lines, db: nil)
        tallies = BOUNDARY_RULES.to_h { |rule| [rule[:key], 0] }

        if db
          count_boundary_from_db(db, tallies)
        else
          each_scannable_token(lines) do |rec|
            BOUNDARY_RULES.each do |rule|
              tallies[rule[:key]] += 1 if rec[:token_raw].match?(rule[:match])
            end
          end
        end

        tallies[:sum] = tallies.values_at(:in, :earth, :the, :amen).sum
        tallies
      end

      def amen_count(lines, db: nil)
        count_tokens(lines, db: db, bucket: :scannable) { |tok| tok == "Amen" }
      end

      def anchor_verse_mentions(lines)
        rules = BOUNDARY_RULES.map { |r| r[:match] }
        total = 0
        [GENESIS, REVELATION].each do |ref|
          text = VerseIndex.verse_text(lines, **ref)
          total += Tokenizer.tokenize(text.to_s).count { |tok| rules.any? { |re| tok.match?(re) } }
        end
        total
      end

      def seven_form_counts(lines, db: nil)
        tallies = SEVEN_FORMS.to_h { |form| [form[:key], 0] }

        if db
          count_seven_forms_from_db(db, tallies)
        else
          token_set_by_form = SEVEN_FORMS.to_h { |f| [f[:key], f[:tokens].to_set] }
          each_scannable_token(lines) do |rec|
            tok = rec[:token_raw]
            token_set_by_form.each do |key, tokens|
              tallies[key] += 1 if tokens.include?(tok)
            end
          end
        end

        tallies[:sum] = tallies.values_at(*SEVEN_FORMS.map { |f| f[:key] }).sum
        tallies
      end

      def in_amen_genesis_revelation(lines, db: nil)
        count_tokens(lines, db: db, bucket: :scannable) do |tok, rec|
          GEN_REV_SET.include?(rec[:book]) && (tok.match?(/\AIn\z/i) || tok == "Amen")
        end
      end

      def the_amen_nt_concealed(lines)
        the_star = 0
        amen = 0
        each_verse_text_token(lines) do |tok, rec|
          next unless NT_BOOK_SET.include?(rec[:book])

          the_star += 1 if the_star_nt_token?(tok)
          amen += 1 if amen_star_nt_token?(tok)
        end
        { the_star: the_star, amen: amen, sum: the_star + amen }
      end

      def the_star_nt_token?(tok)
        tok.match?(THE_STAR_PREFIX) || tok.match?(THE_UPPER_STAR_PREFIX)
      end

      def amen_star_nt_token?(tok)
        tok.match?(AMEN_STAR_PREFIX) || tok.match?(AMEN_UPPER_STAR_PREFIX)
      end

      def god_jesus_genesis_revelation(lines, db: nil)
        god = 0
        jesus = 0
        count_tokens(lines, db: db, bucket: :scannable) do |tok, rec|
          next unless GEN_REV_SET.include?(rec[:book])

          god += 1 if tok.match?(/\AGod\z/i)
          jesus += 1 if tok == "Jesus" || tok == "JESUS"
        end
        { god: god, jesus: jesus, sum: god + jesus }
      end

      def chapter_word_count(lines, book:, chapter:)
        total = 0
        VerseIndex.each_verse(lines) do |b, ch, _v, text|
          total += Tokenizer.tokenize(text).size if b == book && ch == chapter
        end
        total
      end

      def first_last_chapter_word_count(lines)
        gen = chapter_word_count(lines, book: "Genesis", chapter: 1)
        rev = chapter_word_count(lines, book: "Revelation", chapter: 22)
        { genesis: gen, revelation: rev, sum: gen + rev }
      end

      def ot_first_last_chapter_word_count(lines)
        gen = chapter_word_count(lines, book: "Genesis", chapter: 1)
        mal = chapter_word_count(lines, book: "Malachi", chapter: 4)
        { genesis: gen, malachi: mal, sum: gen + mal }
      end

      def god_pure_nt(lines)
        count = 0
        each_verse_text_token(lines) do |tok, rec|
          count += 1 if NT_BOOK_SET.include?(rec[:book]) && god_pure_token?(tok)
        end
        count
      end

      def beginning_end_amen(lines, db: nil)
        beginning = count_tokens(lines, db: db, bucket: :scannable) { |tok| tok.match?(/\Abeginning\z/i) }
        ending = count_tokens(lines, db: db, bucket: :scannable) { |tok| tok.match?(/\Aend\z/i) }
        amen = count_tokens(lines, db: db, bucket: :scannable) { |tok| tok == "Amen" }
        { beginning: beginning, end: ending, amen: amen, sum: beginning + ending + amen }
      end

      def jesus_boundary_same_verse(lines, db: nil)
        verses = verse_token_map(lines, db: db, bucket: :verse_text)
        boundary = 0
        jesus = 0
        verses.each do |key, toks|
          next unless toks.any? { |t| SEVEN_FORM_TOKEN_SET.include?(t) }
          next unless toks.any? { |t| t == "Jesus" }
          next if JESUS_NON_CHRIST_VERSE_SET.include?(key)

          boundary += toks.count { |t| SEVEN_FORM_TOKEN_SET.include?(t) }
          jesus += toks.count { |t| t == "Jesus" }
        end
        { boundary: boundary, jesus: jesus, sum: boundary + jesus }
      end

      def jesus_boundary_first7_nt(lines, db: nil)
        verses = verse_token_map(lines, db: db, bucket: :verse_text)
        count = 0
        verses.each do |(book, _ch, _v), toks|
          next unless FIRST_7_NT_SET.include?(book)
          next unless toks.any? { |t| SEVEN_FORM_TOKEN_SET.include?(t) }
          next unless toks.any? { |t| t == "Jesus" }

          count += toks.count { |t| t == "Jesus" }
        end
        count
      end

      def god_pure_token?(tok)
        GOD_PURE_PATTERNS.any? { |re| tok.match?(re) }
      end

      def seven_form_token?(tok)
        SEVEN_FORM_TOKEN_SET.include?(tok)
      end

      private

      def each_scannable_token(lines, db: nil)
        if db
          buckets = CorpusStore::SCAN_BUCKETS
          placeholders = (["?"] * buckets.length).join(", ")
          db.execute(<<~SQL, buckets).each do |row|
            SELECT book, chapter, verse, token_raw, bucket FROM tokens
            WHERE bucket IN (#{placeholders})
          SQL
            yield({
              book: row[0], chapter: row[1], verse: row[2],
              token_raw: row[3], bucket: row[4]
            })
          end
        else
          require_relative "corpus_indexer"
          require_relative "corpus_store"
          CorpusIndexer.each_token_record(lines) do |rec|
            next unless CorpusStore::SCAN_BUCKETS.include?(rec[:bucket])

            yield rec
          end
        end
      end

      def each_verse_text_token(lines)
        VerseIndex.each_verse(lines) do |book, chapter, verse, text|
          Tokenizer.tokenize(text).each do |tok|
            yield tok, { book: book, chapter: chapter, verse: verse, bucket: "verse_text" }
          end
        end
      end

      def count_tokens(lines, db: nil, bucket: :scannable)
        count = 0
        if bucket == :scannable
          each_scannable_token(lines, db: db) { |rec| count += 1 if yield(rec[:token_raw], rec) }
        else
          each_verse_text_token(lines) { |tok, rec| count += 1 if yield(tok, rec) }
        end
        count
      end

      def verse_token_map(lines, db: nil, bucket: :scannable)
        map = Hash.new { |h, k| h[k] = [] }
        if bucket == :scannable
          each_scannable_token(lines, db: db) do |rec|
            map[[rec[:book], rec[:chapter], rec[:verse]]] << rec[:token_raw]
          end
        else
          each_verse_text_token(lines) do |tok, rec|
            map[[rec[:book], rec[:chapter], rec[:verse]]] << tok
          end
        end
        map
      end

      def count_boundary_from_db(db, tallies)
        buckets = CorpusStore::SCAN_BUCKETS
        placeholders = (["?"] * buckets.length).join(", ")

        BOUNDARY_RULES.each do |rule|
          if rule[:case] == :insensitive
            norm = rule[:label].downcase
            sql = <<~SQL
              SELECT COUNT(*) FROM tokens
              WHERE bucket IN (#{placeholders}) AND token_norm = ?
            SQL
            tallies[rule[:key]] = db.get_first_value(sql, buckets + [norm]).to_i
          else
            sql = <<~SQL
              SELECT COUNT(*) FROM tokens
              WHERE bucket IN (#{placeholders}) AND token_raw = ?
            SQL
            tallies[rule[:key]] = db.get_first_value(sql, buckets + [rule[:label]]).to_i
          end
        end
      end

      def count_seven_forms_from_db(db, tallies)
        buckets = CorpusStore::SCAN_BUCKETS
        placeholders = (["?"] * buckets.length).join(", ")

        SEVEN_FORMS.each do |form|
          tokens = form[:tokens]
          qmarks = (["?"] * tokens.length).join(", ")
          sql = <<~SQL
            SELECT COUNT(*) FROM tokens
            WHERE bucket IN (#{placeholders}) AND token_raw IN (#{qmarks})
          SQL
          tallies[form[:key]] = db.get_first_value(sql, buckets + tokens).to_i
        end
      end
    end
  end
end
