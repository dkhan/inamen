# frozen_string_literal: true

require "test_helper"

class EditionWarmupTest < ActiveSupport::TestCase
  FakeEdition = Struct.new(:edition_id, keyword_init: true) do
    def corpus_text_path = "missing.txt"
    def warm! = self.warmed = true
    attr_accessor :warmed
  end

  test "warm_all can ensure artifacts without loading indexes into memory" do
    editions = {
      "one" => FakeEdition.new(edition_id: "one"),
      "two" => FakeEdition.new(edition_id: "two")
    }

    EditionContext.stub(:all_ids, editions.keys) do
      EditionContext.stub(:new, ->(id) { editions.fetch(id) }) do
        Inamen::CorpusPublisher.stub(:prebuilt_path, "exists.sqlite") do
          Inamen::VerseIndexPublisher.stub(:prebuilt_path, "exists.marshal") do
            Inamen::WordStreamPublisher.stub(:prebuilt_path, "exists.marshal") do
              Inamen::LexiconPublisher.stub(:prebuilt_path, "exists.marshal") do
                Inamen::CanonOrdinalsPublisher.stub(:prebuilt_path, "exists.marshal") do
                  File.stub(:file?, true) do
                    EditionWarmup.warm_all!(build_if_missing: false, load_indexes: false)
                  end
                end
              end
            end
          end
        end
      end
    end

    assert editions.values.none?(&:warmed)
  end
end
