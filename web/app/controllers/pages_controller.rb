# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @engine_version = Inamen::VERSION
    @feature_count = Inamen::Features.catalog.size
    @editions = Edition.ordered.map do |edition|
      {
        id: edition.short_name,
        name: edition.name,
        filename: edition.source_filename,
        bytes: edition.byte_size,
        sha256: edition.source_checksum[0, 16]
      }
    end
  end
end
