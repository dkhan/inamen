# frozen_string_literal: true

require "test_helper"

class SavedFeatureTest < ActiveSupport::TestCase
  def base_attrs(overrides = {})
    {
      name: "Peter",
      edition_id: "kjv_normalized",
      scope_label: "All texts",
      unit: SavedFeature::UNIT_OCCURRENCES,
      mode: "word_count",
      expected_count: 1,
      saved_actual_count: 1,
      search_selection: { "submitted" => "1" },
      search_phrases: { "0" => { "phrase" => "peter" } }
    }.merge(overrides)
  end

  test "accepts the occurrences and verses measures" do
    assert SavedFeature.new(base_attrs(unit: "occurrences")).valid?
    assert SavedFeature.new(base_attrs(unit: "verses")).valid?
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
end
