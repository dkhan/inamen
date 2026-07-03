# frozen_string_literal: true

module Inamen
  # Counts anchored on the first/last tokens of Genesis 1:1 and Revelation 22:21.
  #
  # Genesis 1:1 begins with IN and ends with earth; Revelation 22:21 begins with The
  # and ends with Amen. Each anchor word is counted across scannable text (verse body,
  # psalm superscriptions, colophons) with the stated case rules; the four counts sum
  # to 77,777 on the KJV.
  module BibleBoundaryWords
    GENESIS = { book: "Genesis", chapter: 1, verse: 1 }.freeze
    REVELATION = { book: "Revelation", chapter: 22, verse: 21 }.freeze

    RULES = [
      { key: :in, label: "In", case: :insensitive, anchor: "Genesis 1:1 first word",
        match: /\AIn\z/i },
      { key: :earth, label: "earth", case: :sensitive, anchor: "Genesis 1:1 last word",
        match: /\Aearth\z/ },
      { key: :the, label: "The", case: :insensitive, anchor: "Revelation 22:21 first word",
        match: /\AThe\z/i },
      { key: :amen, label: "Amen", case: :sensitive, anchor: "Revelation 22:21 last word",
        match: /\AAmen\z/ }
    ].freeze

    EXPECTED_SUM = 77_777

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

      def counts(lines, db: nil)
        tallies = RULES.to_h { |rule| [rule[:key], 0] }

        if db
          count_from_db(db, tallies)
        else
          require_relative "corpus_indexer"
          require_relative "corpus_store"
          CorpusIndexer.each_token_record(lines) do |rec|
            next unless CorpusStore::SCAN_BUCKETS.include?(rec[:bucket])

            RULES.each do |rule|
              tallies[rule[:key]] += 1 if rec[:token_raw].match?(rule[:match])
            end
          end
        end

        tallies[:sum] = tallies.values_at(:in, :earth, :the, :amen).sum
        tallies
      end

      private

      def count_from_db(db, tallies)
        buckets = CorpusStore::SCAN_BUCKETS
        placeholders = (["?"] * buckets.length).join(", ")

        RULES.each do |rule|
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
    end
  end
end
