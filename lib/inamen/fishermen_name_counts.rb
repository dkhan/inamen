# frozen_string_literal: true

require "digest"
require "set"
require_relative "fishermen_gospels_kjs"

module Inamen
  # NT name-mention counts for the John 21 fishing party (Peter, Thomas, Nathanael,
  # James son of Zebedee, John apostle son of Zebedee).
  #
  # James and John counts follow the KJPBS antimentions in data/features/fishermen_gospels.kjs:
  # count James*/John* prefix tokens minus any token that falls inside a listed exclusion phrase.
  module FishermenNameCounts
    NT_BOOKS = BookStatsReport::CANON.drop(39).map(&:first).freeze
    GOSPEL_BOOKS = %w[Matthew Mark Luke John].freeze

    # Gospel parallels: James son of Zebedee (19 token occurrences). Retained for regression checks.
    JAMES_SON_OF_ZEBEDEE = {
      ["Matthew", 4, 21] => [11],
      ["Matthew", 10, 2] => [21],
      ["Matthew", 17, 1] => [8],
      ["Mark", 1, 19] => [12],
      ["Mark", 1, 29] => [21],
      ["Mark", 3, 17] => [2, 12],
      ["Mark", 5, 37] => [12, 18],
      ["Mark", 9, 2] => [11],
      ["Mark", 10, 35] => [2],
      ["Mark", 10, 41] => [14],
      ["Mark", 13, 3] => [16],
      ["Mark", 14, 33] => [8],
      ["Luke", 5, 10] => [5],
      ["Luke", 6, 14] => [11],
      ["Luke", 8, 51] => [18],
      ["Luke", 9, 28] => [19],
      ["Luke", 9, 54] => [5]
    }.freeze

    # Gospel parallels plus Luke 22:8 (20 token occurrences). Retained for regression checks.
    JOHN_APOSTLE_SON_OF_ZEBEDEE = {
      ["Matthew", 4, 21] => [17],
      ["Matthew", 10, 2] => [27],
      ["Matthew", 17, 1] => [10],
      ["Mark", 1, 19] => [18],
      ["Mark", 1, 29] => [23],
      ["Mark", 3, 17] => [8],
      ["Mark", 5, 37] => [14],
      ["Mark", 9, 2] => [13],
      ["Mark", 9, 38] => [2],
      ["Mark", 10, 35] => [4],
      ["Mark", 10, 41] => [16],
      ["Mark", 13, 3] => [18],
      ["Mark", 14, 33] => [10],
      ["Luke", 5, 10] => [7],
      ["Luke", 6, 14] => [13],
      ["Luke", 8, 51] => [20],
      ["Luke", 9, 28] => [17],
      ["Luke", 9, 49] => [2],
      ["Luke", 9, 54] => [7],
      ["Luke", 22, 8] => [6]
    }.freeze

    PREFIX_NAMES = {
      peter: "Peter",
      thomas: "Thomas",
      nathanael: "Nathanael"
    }.freeze

    GROSS_PREFIX_KEYS = PREFIX_NAMES.merge(james: "James", john: "John").freeze
    PREFIX_REGEXES = GROSS_PREFIX_KEYS.transform_values { |prefix| /\A#{Regexp.escape(prefix)}/i }.freeze
    STREAM_WILDCARD_PATTERNS = GROSS_PREFIX_KEYS.transform_values { |prefix| "#{prefix}*" }.freeze
    # Cheap verse-text gate before tokenizing; stream misses still covered via target verse set union.
    NAME_TEXT_HINT = /(?:^|[^\p{L}\p{M}])(?:Peter|Thomas|Nathanael|James|John)/i.freeze

    GospelScanBundle = Struct.new(:gross, :gross_spellings, :net, :positions, keyword_init: true)

    def self.counts(lines, scope: :nt)
      both = counts_both(lines)
      case scope
      when :nt then both[:nt]
      when :gospels then both[:gospels]
      else
        raise ArgumentError, "Unknown scope: #{scope.inspect} (use :nt or :gospels)"
      end
    end

    def self.gross_counts(lines, scope: :gospels)
      gospel_scan_bundle(lines, scope: scope).gross
    end

    def self.gross_spellings(lines, scope: :gospels)
      gospel_scan_bundle(lines, scope: scope).gross_spellings
    end

    def self.gospel_scan_bundle(lines, scope: :gospels, james_exclusions: FishermenGospelsKjs.james_exclusions,
                                john_exclusions: FishermenGospelsKjs.john_exclusions, collect_positions: false,
                                word_stream: nil, edition: nil, search_selection: nil)
      stream = word_stream || edition_word_stream(edition)
      if stream && scope == :gospels
        return gospel_scan_bundle_from_stream(
          stream,
          lines: lines,
          james_exclusions: james_exclusions,
          john_exclusions: john_exclusions,
          collect_positions: collect_positions,
          edition: edition,
          search_selection: search_selection
        )
      end

      books = scope_books(scope)
      cache = (Thread.current[:inamen_fishermen_gospel_scan_cache] ||= {})
      cache_key = [lines.__id__, scope, exclusion_fingerprint(james_exclusions), exclusion_fingerprint(john_exclusions), collect_positions]
      return cache[cache_key] if cache.key?(cache_key)

      scan_gospel_bundle(
        lines,
        books: books,
        james_exclusions: james_exclusions,
        john_exclusions: john_exclusions,
        collect_positions: collect_positions,
        cache: cache,
        cache_key: cache_key
      )
    end

    def self.gospel_scan_bundle_from_stream(word_stream, lines:, james_exclusions:, john_exclusions:,
                                            collect_positions: false, edition: nil, search_selection: nil)
      books = scope_books(:gospels)
      selection = resolve_stream_selection(search_selection, books)
      cache = (Thread.current[:inamen_fishermen_gospel_scan_cache] ||= {})
      cache_key = [
        word_stream.object_id,
        lines.__id__,
        :gospels,
        exclusion_fingerprint(james_exclusions),
        exclusion_fingerprint(john_exclusions),
        collect_positions
      ]
      return cache[cache_key] if cache.key?(cache_key)

      target_verses = stream_target_verses(word_stream, selection: selection, books: books)
      scan_gospel_bundle(
        lines,
        books: books,
        james_exclusions: james_exclusions,
        john_exclusions: john_exclusions,
        collect_positions: collect_positions,
        target_verses: target_verses,
        edition: edition,
        cache: cache,
        cache_key: cache_key
      )
    end

    def self.scan_gospel_bundle(lines, books:, james_exclusions:, john_exclusions:, collect_positions:,
                                target_verses: nil, edition: nil, cache: nil, cache_key: nil)
      james_compiled = compile_exclusion_phrases(james_exclusions, "James")
      john_compiled = compile_exclusion_phrases(john_exclusions, "John")
      gross = PREFIX_NAMES.transform_values { 0 }.merge(james: 0, john: 0)
      gross_spellings = GROSS_PREFIX_KEYS.transform_values { Hash.new(0) }
      net = { james: 0, john: 0 }
      positions = collect_positions ? Hash.new { |hash, key| hash[key] = [] } : nil

      VerseIndex.each_verse(lines) do |book, chapter, verse, text|
        next unless books.include?(book)
        verse_key = [book, chapter, verse]
        next unless scan_verse?(text, verse_key, target_verses)

        tokens = Tokenizer.tokenize(text)
        tokens.each_with_index do |tok, idx|
          GROSS_PREFIX_KEYS.each do |key, prefix|
            next unless tok.match?(PREFIX_REGEXES[key])

            gross[key] += 1
            gross_spellings[key][tok] += 1

            case key
            when :james
              next if excluded_by_compiled?(tokens, idx, james_compiled)

              net[:james] += 1
              positions[verse_key] << idx + 1 if collect_positions
            when :john
              next if excluded_by_compiled?(tokens, idx, john_compiled)

              net[:john] += 1
              positions[verse_key] << idx + 1 if collect_positions
            else
              positions[verse_key] << idx + 1 if collect_positions
            end
          end
        end
      end

      bundle = GospelScanBundle.new(
        gross: gross,
        gross_spellings: gross_spellings.transform_values { |hash| sort_spelling_tallies(hash) },
        net: net,
        positions: positions
      )
      cache[cache_key] = bundle if cache && cache_key
      bundle
    end
    private_class_method :scan_gospel_bundle

    def self.stream_target_verses(word_stream, selection:, books:)
      verses = Set.new
      STREAM_WILDCARD_PATTERNS.each_value do |pattern|
        word_stream.positions_for(pattern, case_sensitive: false, selection: selection).each do |position|
          token = word_stream.token_at(position)
          next unless token && books.include?(token.book)

          verses << [token.book, token.chapter, token.verse]
        end
      end
      verses
    end
    private_class_method :stream_target_verses

    def self.scan_verse?(text, verse_key, target_verses)
      return verse_text_relevant?(text) if target_verses.nil?

      verse_text_relevant?(text) || target_verses.include?(verse_key)
    end
    private_class_method :scan_verse?

    def self.verse_text_relevant?(text)
      text.match?(NAME_TEXT_HINT)
    end
    private_class_method :verse_text_relevant?

    def self.counts_both(lines)
      @counts_cache ||= {}
      @counts_cache[lines.__id__] ||= compute_counts_both(lines)
    end

    def self.compute_counts_both(lines)
      nt_books = NT_BOOKS.to_set
      gospel_books = GOSPEL_BOOKS.to_set
      james_exclusions = FishermenGospelsKjs.james_exclusions
      john_exclusions = FishermenGospelsKjs.john_exclusions
      nt = PREFIX_NAMES.transform_values { 0 }.merge(james: 0, john: 0)
      gospels = PREFIX_NAMES.transform_values { 0 }.merge(james: 0, john: 0)

      VerseIndex.each_verse(lines) do |book, _chapter, _verse, text|
        PREFIX_NAMES.each do |key, prefix|
          n = prefix_match_count(text, prefix)
          nt[key] += n if nt_books.include?(book)
          gospels[key] += n if gospel_books.include?(book)
        end
      end

      nt[:james] = count_with_exclusions(lines, gospel_books, "James", james_exclusions)
      nt[:john] = count_with_exclusions(lines, gospel_books, "John", john_exclusions)
      gospels[:james] = count_with_exclusions(lines, gospel_books, "James", james_exclusions)
      gospels[:john] = count_with_exclusions(lines, gospel_books, "John", john_exclusions)
      nt[:sum] = nt.values_at(:peter, :thomas, :nathanael, :james, :john).sum
      gospels[:sum] = gospels.values_at(:peter, :thomas, :nathanael, :james, :john).sum
      { nt: nt, gospels: gospels }
    end
    private_class_method :compute_counts_both

    def self.count_with_exclusions(lines, books, prefix, exclusion_phrases)
      books = books.to_set
      scope = books == GOSPEL_BOOKS.to_set ? :gospels : :nt
      bundle = gospel_scan_bundle(
        lines,
        scope: scope,
        james_exclusions: prefix == "James" ? exclusion_phrases : FishermenGospelsKjs.james_exclusions,
        john_exclusions: prefix == "John" ? exclusion_phrases : FishermenGospelsKjs.john_exclusions
      )
      prefix == "James" ? bundle.net[:james] : bundle.net[:john]
    end

    def self.build_verse_result(lines, scope: :gospels, search_selection: nil, james_exclusions: nil, john_exclusions: nil,
                                word_stream: nil, edition: nil)
      require_relative "canon_index"
      require_relative "verse_match_query"

      books = scope_books(scope)
      selection = resolve_verse_selection(search_selection, books)
      merged = Hash.new { |hash, key| hash[key] = [] }
      james_exclusions ||= FishermenGospelsKjs.james_exclusions
      john_exclusions ||= FishermenGospelsKjs.john_exclusions

      bundle = gospel_scan_bundle(
        lines,
        scope: scope,
        james_exclusions: james_exclusions,
        john_exclusions: john_exclusions,
        collect_positions: true,
        word_stream: word_stream,
        edition: edition,
        search_selection: search_selection
      )
      bundle.positions.each do |(book, chapter, verse), indices|
        merged[[book, chapter, verse, CorpusStore::BUCKET_VERSE_TEXT]].concat(indices)
      end

      verses = merged.map do |(book, chapter, verse, bucket), indices|
        sorted = indices.sort.uniq
        VerseMatchQuery::VerseRow.new(
          book: book,
          chapter: chapter,
          verse: verse,
          bucket: bucket,
          occurrence_count: indices.length,
          highlight_indices: sorted,
          first_hit_index: nil
        )
      end
      verses.sort_by! { |row| CanonIndex.sort_key(row.book, row.chapter, row.verse) + [row.bucket] }
      verses.each_with_index { |row, index| row.first_hit_index = index + 1 }

      VerseMatchQuery::Result.new(
        summary: VerseMatchQuery::Summary.new(
          occurrences: verses.sum(&:occurrence_count),
          verses: verses.length,
          chapters: verses.map { |row| [row.book, row.chapter] }.uniq.length,
          books: verses.map(&:book).uniq.length,
          scope_label: selection.label
        ),
        verses: verses,
        hits: []
      )
    end

    def self.each_matching_position(lines, scope: :gospels, james_exclusions: nil, john_exclusions: nil)
      return enum_for(:each_matching_position, lines, scope: scope, james_exclusions: james_exclusions, john_exclusions: john_exclusions) unless block_given?

      books = scope_books(scope)
      james_exclusions ||= FishermenGospelsKjs.james_exclusions
      john_exclusions ||= FishermenGospelsKjs.john_exclusions

      VerseIndex.each_verse(lines) do |book, chapter, verse, text|
        next unless books.include?(book)

        tokens = Tokenizer.tokenize(text)
        PREFIX_NAMES.each_value do |prefix|
          prefix_re = /\A#{Regexp.escape(prefix)}/i
          tokens.each_with_index do |tok, idx|
            next unless tok.match?(prefix_re)

            yield book, chapter, verse, idx + 1, prefix
          end
        end

        { "James" => james_exclusions, "John" => john_exclusions }.each do |prefix, exclusions|
          prefix_re = /\A#{Regexp.escape(prefix)}/i
          tokens.each_with_index do |tok, idx|
            next unless tok.match?(prefix_re)
            next if excluded_name_index?(tokens, prefix, idx, exclusions)

            yield book, chapter, verse, idx + 1, prefix
          end
        end
      end
    end

    def self.excluded_name_index?(tokens, prefix, idx, exclusion_phrases)
      excluded_by_compiled?(tokens, idx, compile_exclusion_phrases(exclusion_phrases, prefix))
    end
    private_class_method :excluded_name_index?

    def self.compile_exclusion_phrases(exclusion_phrases, prefix)
      exclusion_phrases.map do |phrase|
        words = kjs_phrase_words(phrase)
        anchors = words.each_index.select { |word_index| name_word_in_phrase?(words[word_index], prefix) }
        { words: words, anchors: anchors }
      end
    end
    private_class_method :compile_exclusion_phrases

    def self.excluded_by_compiled?(tokens, idx, compiled_phrases)
      compiled_phrases.any? do |compiled|
        compiled[:anchors].any? do |word_index|
          start = idx - word_index
          next false if start.negative?
          next false if start + compiled[:words].length > tokens.length

          phrase_matches_at?(tokens, start, compiled[:words])
        end
      end
    end
    private_class_method :excluded_by_compiled?

    def self.exclusion_fingerprint(exclusion_phrases)
      Digest::SHA256.hexdigest(Array(exclusion_phrases).join("\0"))
    end
    private_class_method :exclusion_fingerprint

    def self.sort_spelling_tallies(hash)
      hash.sort_by { |raw, count| [-count, raw] }.to_h
    end
    private_class_method :sort_spelling_tallies

    def self.edition_word_stream(edition)
      edition.respond_to?(:word_stream_index) ? edition.word_stream_index : nil
    end
    private_class_method :edition_word_stream

    def self.resolve_stream_selection(search_selection, books)
      if search_selection.is_a?(SearchSelection)
        search_selection
      else
        SearchSelection.new(colophons: false, superscriptions: false, books: books.to_a.sort)
      end
    end
    private_class_method :resolve_stream_selection

    def self.kjs_phrase_words(phrase)
      FishermenGospelsKjs.send(:decode_phrase, phrase.to_s).split(/\s+/).reject(&:empty?)
    end
    private_class_method :kjs_phrase_words

    def self.name_word_in_phrase?(word, prefix)
      if TokenPattern.wildcard?(word)
        word.match?(/\A#{Regexp.escape(prefix)}/i)
      else
        normalize_match_text(word).start_with?(normalize_match_text(prefix))
      end
    end
    private_class_method :name_word_in_phrase?

    def self.phrase_matches_at?(tokens, start, phrase_words)
      phrase_words.each_with_index.all? do |word, offset|
        token_matches_word?(tokens[start + offset], word)
      end
    end
    private_class_method :phrase_matches_at?

    def self.token_matches_word?(token, word)
      if TokenPattern.wildcard?(word)
        wildcard_token = normalize_for_wildcard_match(token)
        TokenPattern.matches?(
          word,
          token_raw: wildcard_token,
          token_norm: CorpusStore.normalize_token(wildcard_token),
          case_sensitive: false
        )
      else
        normalize_match_text(token) == normalize_match_text(word)
      end
    end
    private_class_method :token_matches_word?

    def self.normalize_for_wildcard_match(token)
      text = CorpusStore.normalize_apostrophes(token)
      text.sub(/\A(.+?)['\u{2019}]s\z/i, '\1').sub(TokenPattern::TRAILING_POSSESSIVE, "")
    end
    private_class_method :normalize_for_wildcard_match

    def self.normalize_match_text(text)
      CorpusStore.normalize_apostrophes(text.to_s.downcase).gsub("æ", "ae").gsub(/[^\p{L}\p{M}0-9\-]/, "")
    end
    private_class_method :normalize_match_text

    def self.whitelist_count(whitelist, books)
      whitelist.sum do |(book, _chapter, _verse), indices|
        books.include?(book) ? indices.length : 0
      end
    end
    private_class_method :whitelist_count

    def self.whitelist_matches?(whitelist, lines, name:, texts: nil)
      texts ||= VerseIndex.verse_map(lines)
      whitelist.all? do |ref, expected_indices|
        book, chapter, verse = ref
        text = texts[[book, chapter, verse]]
        return false if text.nil?

        actual = VerseIndex.name_token_indices(text, name)
        actual == expected_indices
      end
    end

    def self.kjs_exclusions_match_whitelist?(lines, name:, whitelist:, exclusion_phrases:)
      books = scope_books(:gospels)
      texts = VerseIndex.verse_map(lines)
      whitelist_positions = []
      whitelist.each do |(book, chapter, verse), indices|
        next unless books.include?(book)

        indices.each { |idx| whitelist_positions << [book, chapter, verse, idx] }
      end

      kjs_positions = []
      VerseIndex.each_verse(lines) do |book, chapter, verse, text|
        next unless books.include?(book)

        tokens = Tokenizer.tokenize(text)
        tokens.each_with_index do |tok, idx|
          next unless tok.match?(/\A#{Regexp.escape(name)}/i)
          next if excluded_name_index?(tokens, name, idx, exclusion_phrases)

          kjs_positions << [book, chapter, verse, idx + 1]
        end
      end

      whitelist_positions.sort == kjs_positions.sort
    end

    def self.prefix_match_count(text, prefix)
      re = /\A#{Regexp.escape(prefix)}/i
      Tokenizer.tokenize(text).count { |tok| tok.match?(re) }
    end
    private_class_method :prefix_match_count

    def self.scope_books(scope)
      case scope
      when :nt then NT_BOOKS.to_set
      when :gospels then GOSPEL_BOOKS.to_set
      else
        raise ArgumentError, "Unknown scope: #{scope.inspect} (use :nt or :gospels)"
      end
    end

    def self.resolve_verse_selection(search_selection, books)
      if search_selection.is_a?(SearchSelection)
        search_selection
      else
        SearchSelection.new(colophons: false, superscriptions: false, books: books.to_a.sort)
      end
    end
    private_class_method :resolve_verse_selection
  end
end
