# frozen_string_literal: true

class Edition < ApplicationRecord
  TYPES = %w[bible].freeze

  has_one :file_stat_snapshot, dependent: :destroy

  validates :short_name, presence: true, uniqueness: true,
                         format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
  validates :name, :source_path, :source_filename, :source_checksum, :byte_size, :imported_at, presence: true
  validates :corpus_type, inclusion: { in: TYPES }

  scope :ordered, -> { order(:created_at, :short_name) }

  def self.default
    ordered.first
  end

  def edition_id
    short_name
  end

  def language
    metadata.to_h["language"].presence || "en"
  end

  def path
    source_path
  end

  def corpus_text_path
    metadata.to_h["processed_path"].presence || source_path
  end

  def lines
    @lines ||= if metadata.to_h["processed_path"].present?
      File.readlines(corpus_text_path, chomp: true)
    else
      Inamen::BibleTextPreprocessor.from_file(source_path).lines
    end
  end

  def source_lines
    @source_lines ||= File.readlines(source_path, chomp: true)
  end
end
