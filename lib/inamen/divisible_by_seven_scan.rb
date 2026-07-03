# frozen_string_literal: true

module Inamen
  # Report token occurrence counts that are divisible by N at various scopes.
  module DivisibleBySevenScan
    SCOPES = %i[whole_bible ot nt].freeze

    ScopeRow = Struct.new(:scope, :token_norm, :token_raw, :count, :divisible_by, keyword_init: true)

    class << self
      def scan(db, divisible_by: 7, scope: :whole_bible, bucket: :default, min_count: 1)
        raise ArgumentError, "divisible_by must be positive" unless divisible_by.to_i.positive?

        rows = aggregate_counts(db, scope: scope, buckets: CorpusStore.resolve_buckets(bucket))
        rows.filter_map do |row|
          count = row[:count]
          next if count < min_count
          next unless (count % divisible_by).zero?

          ScopeRow.new(
            scope: scope_label(scope),
            token_norm: row[:token_norm],
            token_raw: row[:token_raw],
            count: count,
            divisible_by: divisible_by
          )
        end.sort_by { |r| [-r.count, r.token_norm, r.token_raw] }
      end

      def count_for(db, token:, scope: :whole_bible, bucket: :default, exact: false)
        col = exact ? "token_raw" : "token_norm"
        val = exact ? token.to_s : CorpusStore.normalize_token(token)
        buckets = CorpusStore.resolve_buckets(bucket)
        bucket_sql, bucket_params = bucket_clause(buckets)
        where_sql, scope_params = scope_clause(scope)
        params = bucket_params + [val] + scope_params

        sql = <<~SQL
          SELECT COUNT(*) FROM tokens
          WHERE #{bucket_sql} AND #{col} = ? #{where_sql}
        SQL
        db.get_first_value(sql, params).to_i
      end

      def print_scan(db, divisible_by: 7, scope: :whole_bible, bucket: :default, min_count: 1, out: $stdout)
        buckets = CorpusStore.resolve_buckets(bucket)
        rows = scan(db, divisible_by: divisible_by, scope: scope, bucket: bucket, min_count: min_count)
        bucket_label = buckets.length == 1 ? buckets.first : "scannable"
        out.puts "scope\ttoken_norm\ttoken_raw\tcount\tdivisible_by"
        rows.each do |r|
          out.puts "#{r.scope}\t#{r.token_norm}\t#{r.token_raw}\t#{r.count}\t#{r.divisible_by}"
        end
        out.puts "---"
        out.puts "Matches: #{rows.size} (scope=#{scope_label(scope)}, bucket=#{bucket_label}, n%#{divisible_by}=0)"
        rows
      end

      def scope_label(scope)
        scope.to_s.tr("_", " ")
      end

      private

      def aggregate_counts(db, scope:, buckets:)
        bucket_sql, bucket_params = bucket_clause(buckets)
        where_sql, scope_params = scope_clause(scope)
        params = bucket_params + scope_params

        sql = <<~SQL
          SELECT token_norm, token_raw, COUNT(*) AS count
          FROM tokens
          WHERE #{bucket_sql} #{where_sql}
          GROUP BY token_norm, token_raw
        SQL

        db.execute(sql, params).map do |token_norm, token_raw, count|
          { token_norm: token_norm, token_raw: token_raw, count: count.to_i }
        end
      end

      def bucket_clause(buckets)
        placeholders = (["?"] * buckets.length).join(", ")
        ["bucket IN (#{placeholders})", buckets]
      end

      def scope_clause(scope)
        case scope
        when :whole_bible, "whole_bible", "whole"
          ["", []]
        when :ot, "ot"
          ["AND testament = 'OT'", []]
        when :nt, "nt"
          ["AND testament = 'NT'", []]
        else
          book = BookStatsReport::CANON.find { |(name, _, _)| name.casecmp?(scope.to_s) }&.first
          raise ArgumentError, "Unknown scope: #{scope.inspect}" unless book

          ["AND book = ?", [book]]
        end
      end
    end
  end
end
