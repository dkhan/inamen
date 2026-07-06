# frozen_string_literal: true

module Inamen
  # Find words or spellings that share the same occurrence count.
  module EqualCountScan
    MATCH_BY = %i[norm spelling].freeze

    CountGroup = Struct.new(:scope, :count, :words, :match_by, keyword_init: true)
    WordEntry = Struct.new(:token_norm, :token_raws, keyword_init: true)

    class << self
      def scan(db, scope: :whole_bible, bucket: :default, min_count: 1, min_group_size: 2, match_by: :norm)
        match = normalize_match_by(match_by)
        raise ArgumentError, "min_group_size must be at least 2" unless min_group_size.to_i >= 2

        rows = TokenCountQuery.aggregate(db, scope: scope, bucket: bucket, group: :norm_raw)
        groups = case match
                 when :spelling then groups_by_spelling(rows, min_count:, min_group_size:)
                 else groups_by_norm(rows, min_count:, min_group_size:)
                 end

        groups.map do |count, words|
          CountGroup.new(
            scope: TokenCountQuery.scope_label(scope),
            count: count,
            words: words,
            match_by: match
          )
        end.sort_by { |g| [-g.count, -g.words.size, g.words.first.token_norm, g.words.first.token_raws.first.to_s] }
      end

      def print_scan(db, scope: :whole_bible, bucket: :default, min_count: 1, min_group_size: 2,
                     match_by: :norm, out: $stdout)
        rows = scan(db, scope: scope, bucket: bucket, min_count: min_count, min_group_size: min_group_size,
                    match_by: match_by)
        out.puts "scope\tcount\tmatch_by\twords"
        rows.each do |group|
          label = group.words.map { |w| word_label(w, group.match_by) }.join(", ")
          out.puts "#{group.scope}\t#{group.count}\t#{group.match_by}\t#{label}"
        end
        out.puts "---"
        out.puts "Groups: #{rows.size} (match_by=#{match_by}, min_count=#{min_count}, min_group_size=#{min_group_size})"
        rows
      end

      def normalize_match_by(value)
        case value.to_s
        when "spelling", "raw" then :spelling
        else :norm
        end
      end

      def word_label(word, match_by)
        case match_by
        when :spelling
          raw = word.token_raws.first
          raw == word.token_norm ? raw : "#{raw} (#{word.token_norm})"
        else
          word.token_norm
        end
      end

      private

      def groups_by_norm(rows, min_count:, min_group_size:)
        by_norm = build_norm_index(rows)
        by_norm.values.group_by { |entry| entry[:count] }.filter_map do |count, entries|
          next if count < min_count
          next if entries.size < min_group_size

          words = entries.sort_by { |e| e[:token_norm] }.map do |entry|
            WordEntry.new(token_norm: entry[:token_norm], token_raws: entry[:raws].sort.uniq)
          end
          [count, words]
        end
      end

      def groups_by_spelling(rows, min_count:, min_group_size:)
        rows.group_by { |row| row[:count] }.filter_map do |count, members|
          next if count < min_count
          next if members.size < min_group_size

          words = members.sort_by { |m| [m[:token_norm], m[:token_raw]] }.map do |row|
            WordEntry.new(token_norm: row[:token_norm], token_raws: [row[:token_raw]])
          end
          [count, words]
        end
      end

      def build_norm_index(rows)
        rows.each_with_object({}) do |row, index|
          entry = index[row[:token_norm]] ||= { token_norm: row[:token_norm], count: 0, raws: [] }
          entry[:count] += row[:count]
          entry[:raws] << row[:token_raw]
        end
      end
    end
  end
end
