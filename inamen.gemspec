# frozen_string_literal: true

require_relative "lib/inamen/version"

Gem::Specification.new do |spec|
  spec.name = "inamen"
  spec.version = Inamen::VERSION
  spec.authors = ["dkhan"]
  spec.email = ["dkhan@users.noreply.github.com"]

  spec.summary = "Text pattern verification and discovery for plain-text corpora"
  spec.description = "Parser, indexer, and feature catalog for KJV-shaped plain text and related corpora."
  spec.homepage = "https://github.com/dkhan/inamen"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z lib bin inamen.gemspec`.split("\0")
  end
  spec.bindir = "bin"
  spec.executables = ["inamen"]
  spec.require_paths = ["lib"]

  spec.add_dependency "sqlite3", "~> 2.9"
end
