# frozen_string_literal: true

require_relative "token_pattern"

module Inamen
  # KJPBS-style phrase preview, autocomplete, and scan eligibility from a word dictionary.
  class PhraseCompleter
    PreviewSegment = Struct.new(:text, :valid, keyword_init: true)
    BranchAnalysis = Struct.new(:preview, :suggestions, :can_search, keyword_init: true)
    Result = Struct.new(:branches, :can_search, :suggestions, keyword_init: true)

    MAX_SUGGESTIONS = 12

    def initialize(words:, case_sensitive: false)
      @case_sensitive = case_sensitive
      @words = words.map(&:to_s).uniq
      @word_set = @words.to_set
      @words_sorted = @words.sort
      @norm_set = @words.filter_map { |word| CorpusStore.normalize_token(word) unless TokenPattern.wildcard?(word) }.to_set
      @norm_words = build_norm_words(@words)
    end

    def self.from_word_stream(stream, case_sensitive: false)
      words = case_sensitive ? stream.postings_raw.keys : stream.postings_raw.keys.uniq
      new(words: words, case_sensitive: case_sensitive)
    end

    def analyze(phrase)
      branch_texts = phrase.to_s.split("|").map(&:strip).reject(&:empty?)
      return empty_result if branch_texts.empty?

      branches = branch_texts.map { |branch| analyze_branch(branch) }
      active = branches.max_by { |branch| branch.preview.length } || branches.first
      Result.new(
        branches: branches,
        can_search: branches.any?(&:can_search),
        suggestions: active&.suggestions || []
      )
    end

    def can_search?(phrase)
      analyze(phrase).can_search
    end

    private

    def empty_result
      Result.new(branches: [], can_search: false, suggestions: [])
    end

    def analyze_branch(text)
      tokens = split_input(text)
      preview = build_preview(tokens)
      suggestions = suggestions_for(tokens)
      can_search = tokens[:partial].nil? && tokens[:complete].any? && tokens[:complete].all? { |token| valid_complete_token?(token) }

      BranchAnalysis.new(preview: preview, suggestions: suggestions, can_search: can_search)
    end

    def split_input(text)
      return { complete: [], partial: nil } if text.empty?

      if text.match?(/\s\z/)
        return { complete: text.strip.split(/\s+/).reject(&:empty?), partial: nil }
      end

      parts = text.split(/\s+/)
      if parts.length == 1
        token = parts.first
        return { complete: [token], partial: nil } if valid_complete_token?(token)

        return { complete: [], partial: token }
      end

      last = parts.last
      complete = parts[0..-2]
      if valid_complete_token?(last)
        { complete: complete + [last], partial: nil }
      else
        { complete: complete, partial: last }
      end
    end

    def build_preview(tokens)
      segments = tokens[:complete].map do |token|
        PreviewSegment.new(text: token, valid: valid_complete_token?(token))
      end

      if tokens[:partial]
        partial_valid =
          if TokenPattern.wildcard?(tokens[:partial])
            valid_partial_token?(tokens[:partial])
          else
            false
          end
        segments << PreviewSegment.new(text: tokens[:partial], valid: partial_valid)
      end

      segments
    end

    def suggestions_for(tokens)
      prefix = tokens[:partial]
      return [] if prefix.nil? || prefix.empty?

      if TokenPattern.wildcard?(prefix)
        wildcard_suggestions(prefix)
      else
        prefix_suggestions(prefix)
      end
    end

    def prefix_suggestions(prefix)
      if @case_sensitive
        prefix_matches(@words_sorted, prefix)
      else
        norm_prefix = CorpusStore.normalize_token(prefix)
        matches = @norm_words.keys.select { |norm| norm.start_with?(norm_prefix) }
        matches.flat_map { |norm| @norm_words[norm] }.uniq.sort.first(MAX_SUGGESTIONS)
      end
    end

    def prefix_matches(words, prefix)
      words.select { |word| word.start_with?(prefix) }.first(MAX_SUGGESTIONS)
    end

    def wildcard_suggestions(pattern)
      regex = TokenPattern.to_regex(pattern, case_sensitive: @case_sensitive)
      @words_sorted.select { |word| regex.match?(wildcard_match_text(word, pattern)) }.first(MAX_SUGGESTIONS)
    end

    def valid_complete_token?(token)
      return false if token.empty?

      if TokenPattern.wildcard?(token)
        wildcard_suggestions(token).any?
      elsif @case_sensitive
        CorpusStore.apostrophe_equivalent_strings(token).any? { |variant| @word_set.include?(variant) }
      else
        @norm_set.include?(CorpusStore.normalize_token(token))
      end
    end

    def valid_partial_token?(token)
      return false if token.empty?

      if TokenPattern.wildcard?(token)
        wildcard_suggestions(token).any? || token.include?("*")
      elsif @case_sensitive
        @words_sorted.any? { |word| word.start_with?(token) }
      else
        norm_prefix = CorpusStore.normalize_token(token)
        @norm_words.keys.any? { |norm| norm.start_with?(norm_prefix) }
      end
    end

    def wildcard_match_text(word, pattern)
      text = CorpusStore.normalize_apostrophes(word)
      return text unless TokenPattern.strip_trailing_possessive_for_wildcard?(pattern)

      text.sub(TokenPattern::TRAILING_POSSESSIVE, "")
    end

    def build_norm_words(words)
      words.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |word, index|
        next if TokenPattern.wildcard?(word)

        index[CorpusStore.normalize_token(word)] << word
      end.transform_values { |list| list.uniq.sort }
    end
  end
end
