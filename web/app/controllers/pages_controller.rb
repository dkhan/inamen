# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @engine_version = Inamen::VERSION
    @feature_count = Inamen::Features.catalog.size
    @editions = Inamen::KjvEditions::EDITIONS.map do |id, path|
      {
        id: id,
        filename: File.basename(path),
        bytes: File.size(path),
        sha256: Digest::SHA256.file(path).hexdigest[0, 16]
      }
    end
  end
end
