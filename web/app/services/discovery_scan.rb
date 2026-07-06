# frozen_string_literal: true

# Runs and caches divisibility discovery scans for an edition corpus.
class DiscoveryScan
  Params = Struct.new(:divisible_by, :scope, :bucket, :min_count, keyword_init: true)

  ResultRow = Struct.new(:scope, :token_norm, :token_raw, :count, :divisible_by, keyword_init: true)

  SCOPES = %w[whole_bible ot nt].freeze
  BUCKETS = %w[default verse_text psalm_heading colophon].freeze

  def self.normalize(raw)
    divisible_by = raw[:divisible_by].to_i
    min_count = raw[:min_count].to_i
    scope = raw[:scope].to_s
    bucket = raw[:bucket].to_s

    Params.new(
      divisible_by: divisible_by.positive? ? divisible_by : 7,
      scope: SCOPES.include?(scope) ? scope : "whole_bible",
      bucket: BUCKETS.include?(bucket) ? bucket : "default",
      min_count: min_count.positive? ? min_count : 7
    )
  end

  def self.run(edition, params, force: false)
    key = cache_key_for(edition, params)
    Rails.cache.delete(key) if force

    Rails.cache.fetch(key, expires_in: 7.days) do
      compute(edition, params)
    end
  end

  def self.compute(edition, params)
    scope_sym = params.scope.to_sym
    bucket = params.bucket == "default" ? :default : params.bucket

    Inamen::DivisibleBySevenScan.scan(
      edition.db,
      divisible_by: params.divisible_by,
      scope: scope_sym,
      bucket: bucket,
      min_count: params.min_count
    ).map do |row|
      ResultRow.new(
        scope: row.scope,
        token_norm: row.token_norm,
        token_raw: row.token_raw,
        count: row.count,
        divisible_by: row.divisible_by
      )
    end
  end

  def self.cached?(edition, params)
    key = cache_key_for(edition, params)
    return false unless Rails.cache.exist?(key)

    value = Rails.cache.read(key)
    !value.nil?
  rescue TypeError
    Rails.cache.delete(key)
    false
  end

  def self.read_cached(edition, params)
    Rails.cache.read(cache_key_for(edition, params))
  rescue TypeError
    clear_cache!(edition, params)
    nil
  end

  def self.clear_cache!(edition, params)
    Rails.cache.delete(cache_key_for(edition, params))
  end

  def self.running?(edition, params)
    Rails.cache.exist?(running_key_for(edition, params))
  end

  def self.running_key_for(edition, params)
    "#{cache_key_for(edition, params)}/running"
  end

  def self.cache_key_for(edition, params)
    p = params.is_a?(Params) ? params : normalize(params)
    [
      "discovery_scan/v1",
      edition.edition_id,
      edition.checksum_prefix,
      Inamen::CorpusStore::INDEXER_REVISION,
      p.divisible_by,
      p.scope,
      p.bucket,
      p.min_count
    ]
  end
end
