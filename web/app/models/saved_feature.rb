# frozen_string_literal: true

class SavedFeature < ApplicationRecord
  URL_PREFIX = "saved_"
  DEFAULT_DESCRIPTION = "Saved from Discover"

  validates :name, presence: true
  validates :edition_id, presence: true
  validates :scope_label, presence: true
  validates :unit, presence: true
  validates :expected_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :saved_actual_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :mode, presence: true
  validates :search_selection, presence: true
  validates :search_phrases, presence: true

  before_validation :ensure_search_selection

  def url_id
    "#{URL_PREFIX}#{id}"
  end

  def display_description
    description.presence || DEFAULT_DESCRIPTION
  end

  def self.url_id?(value)
    value.to_s.start_with?(URL_PREFIX)
  end

  def self.find_by_url_id!(value)
    raise ActiveRecord::RecordNotFound unless url_id?(value)

    find(value.to_s.delete_prefix(URL_PREFIX))
  end

  def to_scan_params
    inferred_feature = from_feature.presence
    unless inferred_feature.present?
      terms = DiscoveryScan.query_terms_from_phrases(search_phrases)
      inferred_feature = Inamen::FeatureDiscoverPresets.resolve_from_feature(nil, query_terms: terms)
    end

    DiscoveryScan.normalize(
      mode: mode,
      search_selection: search_selection,
      search_phrases: search_phrases,
      from_feature: inferred_feature
    )
  end

  def self.build_details_from_phrases(phrases)
    normalize_phrases_hash(phrases).sort_by { |key, _| key.to_i }.filter_map do |_, row|
      phrase = row["phrase"].to_s.strip
      next if phrase.empty?

      flags = []
      flags << "case_sensitive" if truthy?(row["case_sensitive"])
      flags << "exclude" if truthy?(row["exclude"])
      flags << "disabled" if truthy?(row["disabled"])
      flag_text = flags.empty? ? "" : " [#{flags.join(", ")}]"
      "#{phrase}#{flag_text}"
    end
  end

  def self.scope_label_for(search_selection)
    Inamen::SearchSelection.from_params(search_selection).label
  end

  def self.normalize_phrases_hash(phrases)
    return {} if phrases.blank?

    if phrases.is_a?(ActionController::Parameters)
      phrases.permit!.to_h
    else
      phrases.to_h
    end
  end

  def self.truthy?(value)
    value == true || value == 1 || value.to_s == "1" || value.to_s.casecmp("true").zero?
  end
  private_class_method :normalize_phrases_hash, :truthy?

  private

  def ensure_search_selection
    return if search_selection.is_a?(Hash) && search_selection.present?

    self.search_selection = Inamen::SearchSelection.default.to_query_hash
  end
end
