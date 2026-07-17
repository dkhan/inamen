# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @engine_version = Inamen::VERSION
    @feature_count = SavedFeature.count
    @editions = Edition.ordered.map do |edition|
      {
        id: edition.short_name,
        name: edition.name,
        filename: edition.source_filename,
        bytes: edition.byte_size
      }
    end
  end
end
