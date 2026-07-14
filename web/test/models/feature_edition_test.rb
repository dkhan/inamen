# frozen_string_literal: true

require "test_helper"

class FeatureEditionTest < ActiveSupport::TestCase
  def build_feature(name: "F")
    SavedFeature.create!(
      name: name,
      original_edition_id: "kjv_normalized",
      scope_label: "All texts",
      unit: "occurrences",
      mode: "word_count",
      expected_count: 1,
      search_selection: { "submitted" => "1" },
      search_phrases: { "0" => { "phrase" => "peter" } }
    )
  end

  def attrs(overrides = {})
    { edition_id: "kjv_normalized", actual: 1, status: "match",
      processing_state: "verified", verified_at: Time.current }.merge(overrides)
  end

  test "is unique per (feature, edition)" do
    feature = build_feature
    feature.feature_editions.create!(attrs)

    duplicate = feature.feature_editions.build(attrs(actual: 2))
    refute duplicate.valid?
    assert_includes duplicate.errors[:feature_id], "has already been taken"
  end

  test "the same edition may be recorded for different features" do
    a = build_feature(name: "A")
    b = build_feature(name: "B")
    a.feature_editions.create!(attrs)

    assert b.feature_editions.create!(attrs).persisted?
  end

  test "status and processing_state expose predicates" do
    record = build_feature.feature_editions.create!(attrs(status: "miss"))
    assert record.status_miss?
    assert record.processing_verified?
    refute record.match?
  end
end
