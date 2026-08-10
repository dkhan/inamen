# frozen_string_literal: true

class FileStatCategory < ApplicationRecord
  belongs_to :file_stat_snapshot
end
