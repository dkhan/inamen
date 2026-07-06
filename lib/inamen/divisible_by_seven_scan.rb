# frozen_string_literal: true

module Inamen
  # Report token occurrence counts that are divisible by N at various scopes.
  module DivisibleBySevenScan
    SCOPES = %i[whole_bible ot nt].freeze

    ScopeRow = Struct.new(:scope, :token_norm, :token_raw, :count, :divisible_by, keyword_init: true)

    class << self
      def scan(db, divisible_by: 7, search_selection: nil, scope: :whole_bible, bucket: :default, min_count: 1)
        raise ArgumentError, "divisible_by must be positive" unless divisible_by.to_i.positive?

        selection = resolve_selection(search_selection, scope, bucket)
        rows = TokenCountQuery.aggregate(db, search_selection: selection, group: :norm_raw)
        rows.filter_map do |row|
          count = row[:count]
          next if count < min_count
          next unless (count % divisible_by).zero?

          ScopeRow.new(
            scope: TokenCountQuery.selection_label(selection),
            token_norm: row[:token_norm],
            token_raw: row[:token_raw],
            count: count,
            divisible_by: divisible_by
          )
        end.sort_by { |r| [-r.count, r.token_norm, r.token_raw] }
      end

      def count_for(db, token:, search_selection: nil, scope: :whole_bible, bucket: :default, exact: false)
        selection = resolve_selection(search_selection, scope, bucket)
        col = exact ? "token_raw" : "token_norm"
        val = exact ? CorpusStore.normalize_apostrophes(token.to_s) : CorpusStore.normalize_token(token)
        where_sql, where_params = selection.where_clause
        params = [val] + where_params

        if CorpusStore.token_counts_available?(db)
          sql = <<~SQL
            SELECT COALESCE(SUM(count), 0) FROM token_counts
            WHERE #{col} = ? #{where_sql}
          SQL
          return db.get_first_value(sql, params).to_i
        end

        sql = <<~SQL
          SELECT COUNT(*) FROM tokens
          WHERE #{col} = ? #{where_sql}
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
        out.puts "Matches: #{rows.size} (scope=#{TokenCountQuery.scope_label(scope)}, bucket=#{bucket_label}, n%#{divisible_by}=0)"
        rows
      end

      def scope_label(scope)
        TokenCountQuery.scope_label(scope)
      end

      def resolve_selection(search_selection, scope, bucket)
        return search_selection if search_selection.is_a?(SearchSelection)

        SearchSelection.from_legacy(scope: scope, bucket: bucket)
      end
      private :resolve_selection
    end
  end
end
