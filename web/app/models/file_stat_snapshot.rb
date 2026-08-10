# frozen_string_literal: true

class FileStatSnapshot < ApplicationRecord
  belongs_to :edition
  has_many :nodes, class_name: "FileStatNode", dependent: :delete_all
  has_many :categories, class_name: "FileStatCategory", dependent: :delete_all
  has_many :characters, class_name: "FileStatCharacter", dependent: :delete_all

  validates :edition_id, uniqueness: true
end
