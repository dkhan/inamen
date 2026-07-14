# frozen_string_literal: true

# Runs and caches full feature verification for an edition.
class FeatureCatalog
  ResultRow = Struct.new(
    :id, :name, :description, :count, :expected, :unit, :scope, :match,
    :kjvcode_expected, :kjvcode_match, :kjvcode_url, :notes, :details,
    keyword_init: true
  )

  def self.run_all(edition, force: false)
    cache_key = cache_key_for(edition)
    Rails.cache.delete(cache_key) if force

    Rails.cache.fetch(cache_key, expires_in: 7.days) do
      compute_all(edition)
    end
  end

  def self.compute_all(edition)
    Inamen::Features.run_all(
      lines: edition.lines,
      db: edition.db,
      path: edition.path,
      edition_id: edition.edition_id
    ).map do |result|
      build_row(edition, result)
    end
  end

  def self.read_cached(edition)
    Rails.cache.read(cache_key_for(edition))
  rescue TypeError
    clear_cache!(edition)
    nil
  end

  def self.cached?(edition)
    key = cache_key_for(edition)
    return false unless Rails.cache.exist?(key)

    value = Rails.cache.read(key)
    return false if value.nil?

    true
  rescue TypeError
    Rails.cache.delete(key)
    false
  end

  def self.clear_cache!(edition)
    Rails.cache.delete(cache_key_for(edition))
  end

  def self.verification_running?(edition)
    Rails.cache.exist?(running_key_for(edition))
  end

  def self.running_key_for(edition)
    "#{cache_key_for(edition)}/running"
  end

  def self.find_row(edition, feature_id)
    return unless cached?(edition)

    read_cached(edition).find { |row| row.id == feature_id }
  end

  def self.run_one(edition, feature_id)
    result = Inamen::Features.run(
      feature_id,
      lines: edition.lines,
      db: edition.db,
      path: edition.path,
      edition_id: edition.edition_id
    )
    build_row(edition, result)
  end

  def self.build_row(edition, result)
    entry = Inamen::Features.fetch(result.id)
    expected = edition.expected_count(result.id)
    kjvcode = entry.kjvcode_expected_count
    ResultRow.new(
      id: result.id,
      name: result.name,
      description: result.description,
      count: result.count,
      expected: expected,
      unit: result.unit,
      scope: result.scope,
      match: result.count == expected,
      kjvcode_expected: kjvcode,
      kjvcode_match: kjvcode.nil? || result.count == kjvcode,
      kjvcode_url: entry.kjvcode_url,
      notes: result.notes,
      details: result.details
    )
  end

  def self.cache_key_for(edition)
    [
      "feature_catalog/v7",
      edition.edition_id,
      edition.checksum_prefix,
      Inamen::CorpusStore::INDEXER_REVISION
    ]
  end

  private_class_method :build_row
end
