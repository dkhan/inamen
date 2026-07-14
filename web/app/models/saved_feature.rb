# frozen_string_literal: true

class SavedFeature < ApplicationRecord
  URL_PREFIX = "saved_"
  DEFAULT_DESCRIPTION = "Saved from Discover"

  # Measures a saved feature can track. "occurrences" counts every token match;
  # "verses" counts distinct matching verses.
  UNIT_OCCURRENCES = "occurrences"
  UNIT_VERSES = "verses"
  UNITS = [UNIT_OCCURRENCES, UNIT_VERSES].freeze

  # What kind of corpus a feature is meant to be verified against.
  FEATURE_TYPES = { bible: "bible", general_text: "general_text", both: "both" }.freeze

  enum :feature_type, FEATURE_TYPES, default: :bible

  # Per-edition verification results (actual/status) live here, so one feature can
  # be verified against many editions without touching its expected value.
  has_many :feature_editions, foreign_key: :feature_id, inverse_of: :saved_feature, dependent: :destroy

  # Transient actual count for the create form; persisted in a FeatureEdition.
  attr_accessor :actual

  validates :name, presence: true
  validates :original_edition_id, presence: true
  validates :feature_type, presence: true
  validates :scope_label, presence: true
  validates :unit, presence: true, inclusion: { in: UNITS }
  validates :expected_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :mode, presence: true
  validates :search_selection, presence: true
  validates :search_phrases, presence: true

  before_validation :ensure_search_selection

  def url_id
    "#{URL_PREFIX}#{id}"
  end

  def verses?
    unit == UNIT_VERSES
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
    DiscoveryScan.normalize(
      mode: mode,
      search_selection: search_selection,
      search_phrases: search_phrases
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
