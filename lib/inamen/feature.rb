# frozen_string_literal: true

module Inamen
  # Result of evaluating a named biblical pattern feature.
  FeatureResult = Struct.new(
    :id,
    :name,
    :count,
    :unit,
    :scope,
    :description,
    :notes,
    :details,
    :kjvcode_url,
    keyword_init: true
  )

  # Catalog entry describing a reproducible pattern (definition lives in Features.run).
  FeatureEntry = Struct.new(
    :id,
    :name,
    :description,
    :expected_count,
    :unit,
    :scope,
    :notes,
    :kjvcode_expected_count,
    :kjvcode_url,
    keyword_init: true
  )
end
