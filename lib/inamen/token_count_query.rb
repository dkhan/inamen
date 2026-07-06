# frozen_string_literal: true

module Inamen
  # Shared SQL scope/bucket filters for token-count discovery scans.
  module TokenCountQuery
    class << self
      def aggregate(db, scope:, bucket:, group: :norm_raw)
        buckets = CorpusStore.resolve_buckets(bucket)
        bucket_sql, bucket_params = bucket_clause(buckets)
        where_sql, scope_params = scope_clause(scope)
        params = bucket_params + scope_params
        group_sql = group == :norm ? "token_norm" : "token_norm, token_raw"
        select_sql = group == :norm ? "token_norm, NULL AS token_raw" : "token_norm, token_raw"

        sql = <<~SQL
          SELECT #{select_sql}, COUNT(*) AS count
          FROM tokens
          WHERE #{bucket_sql} #{where_sql}
          GROUP BY #{group_sql}
        SQL

        db.execute(sql, params).map do |token_norm, token_raw, count|
          { token_norm: token_norm, token_raw: token_raw, count: count.to_i }
        end
      end

      def spellings_for_token(db, token:, scope:, bucket:, case_sensitive:)
        buckets = CorpusStore.resolve_buckets(bucket)
        bucket_sql, bucket_params = bucket_clause(buckets)
        where_sql, scope_params = scope_clause(scope)
        if case_sensitive
          column = "token_raw"
          value = CorpusStore.normalize_apostrophes(token.to_s)
        else
          column = "token_norm"
          value = CorpusStore.normalize_token(token)
        end

        sql = <<~SQL
          SELECT token_raw, COUNT(*) AS count
          FROM tokens
          WHERE #{bucket_sql} AND #{column} = ? #{where_sql}
          GROUP BY token_raw
          ORDER BY count DESC, token_raw
        SQL
        db.execute(sql, bucket_params + [value] + scope_params).to_h { |raw, count| [raw, count.to_i] }
      end

      def wildcard_aggregate(db, pattern:, scope:, bucket:, case_sensitive:)
        prefilter = TokenPattern.sql_prefilter(pattern, case_sensitive: case_sensitive)
        return aggregate(db, scope: scope, bucket: bucket, group: :norm_raw) if prefilter == :full

        buckets = CorpusStore.resolve_buckets(bucket)
        bucket_sql, bucket_params = bucket_clause(buckets)
        where_sql, scope_params = scope_clause(scope)
        filter_sql, filter_params =
          case prefilter[:op]
          when :like
            ["AND #{prefilter[:column]} LIKE ? ESCAPE '\\'", [prefilter[:value]]]
          when :glob
            ["AND #{prefilter[:column]} GLOB ?", [prefilter[:value]]]
          end

        sql = <<~SQL
          SELECT token_norm, token_raw, COUNT(*) AS count
          FROM tokens
          WHERE #{bucket_sql} #{filter_sql} #{where_sql}
          GROUP BY token_norm, token_raw
        SQL
        params = bucket_params + filter_params + scope_params
        db.execute(sql, params).map do |token_norm, token_raw, count|
          { token_norm: token_norm, token_raw: token_raw, count: count.to_i }
        end
      end

      def scope_label(scope)
        scope.to_s.tr("_", " ")
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
