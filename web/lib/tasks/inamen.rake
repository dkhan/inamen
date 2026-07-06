# frozen_string_literal: true

namespace :inamen do
  namespace :corpora do
    desc "Build prebuilt SQLite corpora for all bundled editions (set FORCE=1 to rebuild)"
    task prebuild: :environment do
      force = ENV["FORCE"] == "1"
      Inamen::CorpusPublisher.build_all_prebuilt!(force: force).each do |built_path|
        puts built_path
      end
    end
  end
end
