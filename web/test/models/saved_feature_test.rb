# frozen_string_literal: true

require "test_helper"

class SavedFeatureTest < ActiveSupport::TestCase
  def base_attrs(overrides = {})
    {
      name: "Peter",
      original_edition_id: "kjv_normalized",
      scope_label: "All texts",
      unit: SavedFeature::UNIT_OCCURRENCES,
      mode: "word_count",
      expected_count: 1,
      search_selection: { "submitted" => "1" },
      search_phrases: { "0" => { "phrase" => "peter" } }
    }.merge(overrides)
  end

  test "accepts word-count and file-stats measures" do
    assert SavedFeature.new(base_attrs(unit: "occurrences")).valid?
    assert SavedFeature.new(base_attrs(unit: "verses")).valid?
    assert SavedFeature.new(base_attrs(unit: "tokens", mode: "file_stats", search_phrases: {})).valid?
    assert SavedFeature.new(base_attrs(unit: "characters", mode: "file_stats", search_phrases: {})).valid?
  end

  test "rejects an unknown measure" do
    feature = SavedFeature.new(base_attrs(unit: "bananas"))

    refute feature.valid?
    assert_includes feature.errors[:unit], "is not included in the list"
  end

  test "verses? reflects the selected measure" do
    assert SavedFeature.new(base_attrs(unit: "verses")).verses?
    refute SavedFeature.new(base_attrs(unit: "occurrences")).verses?
  end

  test "defaults feature_type to bible" do
    assert_equal "bible", SavedFeature.new(base_attrs).feature_type
    assert SavedFeature.new(base_attrs).bible?
  end

  test "accepts the three feature types" do
    %w[bible general_text both].each do |type|
      assert SavedFeature.new(base_attrs(feature_type: type)).valid?, "#{type} should be valid"
    end
  end

  test "rejects an unknown feature type" do
    assert_raises(ArgumentError) { SavedFeature.new(base_attrs(feature_type: "audio")) }
  end

  test "requires an original edition" do
    feature = SavedFeature.new(base_attrs(original_edition_id: nil))
    refute feature.valid?
    assert_includes feature.errors[:original_edition_id], "can't be blank"
  end

  test "destroying a feature removes its feature editions" do
    feature = SavedFeature.create!(base_attrs)
    feature.feature_editions.create!(edition_id: "kjv_normalized", actual: 1, status: "match",
                                     processing_state: "verified", verified_at: Time.current)
    assert_difference "FeatureEdition.count", -1 do
      feature.destroy!
    end
  end
end
