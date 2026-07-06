# frozen_string_literal: true

module Inamen
  # Shared SQL filters for token-count discovery scans.
  module TokenCountQuery
    class << self
      def aggregate(db, search_selection: nil, scope: nil, bucket: nil, group: :norm_raw)
        selection = resolve_selection(search_selection:, scope:, bucket:)
        where_sql, where_params = selection.where_clause
        group_sql = group == :norm ? "token_norm" : "token_norm, token_raw"
        select_sql = group == :norm ? "token_norm, NULL AS token_raw" : "token_norm, token_raw"

        sql = <<~SQL
          SELECT #{select_sql}, COUNT(*) AS count
          FROM tokens
          WHERE 1=1 #{where_sql}
          GROUP BY #{group_sql}
        SQL

        db.execute(sql, where_params).map do |token_norm, token_raw, count|
          { token_norm: token_norm, token_raw: token_raw, count: count.to_i }
        end
      end

      def spellings_for_token(db, token:, search_selection: nil, scope: nil, bucket: nil, case_sensitive:)
        selection = resolve_selection(search_selection:, scope:, bucket:)
        where_sql, where_params = selection.where_clause
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
          WHERE #{column} = ? #{where_sql}
          GROUP BY token_raw
          ORDER BY count DESC, token_raw
        SQL
        db.execute(sql, [value] + where_params).to_h { |raw, count| [raw, count.to_i] }
      end

      def wildcard_aggregate(db, pattern:, search_selection: nil, scope: nil, bucket: nil, case_sensitive:)
        selection = resolve_selection(search_selection:, scope:, bucket:)
        prefilter = TokenPattern.sql_prefilter(pattern, case_sensitive: case_sensitive)
        return aggregate(db, search_selection: selection, group: :norm_raw) if prefilter == :full

        where_sql, where_params = selection.where_clause
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
          WHERE 1=1 #{filter_sql} #{where_sql}
          GROUP BY token_norm, token_raw
        SQL
        params = filter_params + where_params
        db.execute(sql, params).map do |token_norm, token_raw, count|
          { token_norm: token_norm, token_raw: token_raw, count: count.to_i }
        end
      end

      def selection_label(search_selection)
        search_selection.label
      end

      def scope_label(scope)
        scope.to_s.tr("_", " ")
      end

      # Legacy helpers retained for existing call sites.
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

      private

      def resolve_selection(search_selection:, scope:, bucket:)
        return search_selection if search_selection.is_a?(SearchSelection)
        return SearchSelection.default if scope.nil? && bucket.nil?

        SearchSelection.from_legacy(scope: scope || :whole_bible, bucket: bucket || :default)
      end
    end
  end
end
