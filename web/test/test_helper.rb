# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "digest"
require "rails/test_help"

# This build of Minitest ships without minitest/mock, so provide the small subset
# of Object#stub the tests rely on: temporarily replace a (singleton) method with
# a fixed value or callable for the duration of the block, then restore it.
class Object
  def stub(name, value_or_callable, &block)
    original = method(name) if respond_to?(name, true)
    callable = value_or_callable.respond_to?(:call) ? value_or_callable : ->(*, **) { value_or_callable }
    define_singleton_method(name) { |*args, **kwargs| callable.call(*args, **kwargs) }
    block.call
  ensure
    singleton_class.send(:remove_method, name)
    define_singleton_method(name, original) if original
  end
end

module ActiveSupport
  class TestCase
    # Run tests serially; the suite is small and relies on class-level stubs.
    setup :ensure_test_editions

    private

    def ensure_test_editions
      data_root = Rails.root.join("..", "data").expand_path
      {
        "kjv_normalized" => "KJV.txt",
        "concord" => "Holy-Bible-King-James-Version-Entire-Bible-Concord.txt"
      }.each do |short_name, filename|
        path = data_root.join(filename)
        next unless path.file?

        Edition.find_or_create_by!(short_name: short_name) do |edition|
          edition.name = short_name.tr("_", " ").capitalize
          edition.corpus_type = "bible"
          edition.source_path = path.to_s
          edition.source_filename = filename
          edition.source_checksum = ::Digest::SHA256.file(path).hexdigest
          edition.byte_size = path.size
          edition.imported_at = Time.current
          edition.metadata = {}
        end
      end
    end
  end
end
