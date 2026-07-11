# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inamen::FeatureDiscoverPresets do
  describe ".discoverable?" do
    it "includes amen_77 and fishermen_gospels" do
      expect(described_class.discoverable?("amen_77")).to be(true)
      expect(described_class.discoverable?("fishermen_gospels")).to be(true)
    end

    it "includes boundary_anchor_verses with bible boundary phrases" do
      expect(described_class.discoverable?("boundary_anchor_verses")).to be(true)
      expect(described_class.phrase_entries_for("boundary_anchor_verses")).to eq(
        described_class.phrase_entries_for("bible_boundary_words")
      )
    end

    it "includes combined_total and file_character_total as file stats" do
      expect(described_class.discoverable?("combined_total")).to be(true)
      expect(described_class.discoverable?("file_character_total")).to be(true)
      expect(described_class.discover_mode_for("combined_total")).to eq("file_stats")
      expect(described_class.discover_highlight_for("combined_total")).to eq("combined_total")
      expect(described_class.discover_highlight_for("file_character_total")).to eq("file_characters")
    end
  end

  describe ".phrase_entries_for" do
    it "maps bible_boundary_words to four phrases" do
      entries = described_class.phrase_entries_for("bible_boundary_words")
      expect(entries.map { |entry| entry[:phrase] }).to eq(%w[In earth The Amen])
      expect(entries[1][:case_sensitive]).to be(true)
      expect(entries[3][:case_sensitive]).to be(true)
    end

    it "includes possessive Jesus for jesus_mentions" do
      entries = described_class.phrase_entries_for("jesus_mentions")
      expect(entries.first[:phrase]).to include("Jesus")
      expect(entries.first[:phrase]).to include(described_class::JESUS_POSSESSIVE)
      expect(entries.first[:case_sensitive]).to be(true)
    end

    it "maps jesus_boundary_same_verse to boundary words plus Jesus" do
      entries = described_class.phrase_entries_for("jesus_boundary_same_verse")
      expect(entries.map { |entry| entry[:phrase] }).to eq(
        %w[In earth The Amen] + [described_class::JESUS_PHRASE]
      )
    end

    it "maps fishermen_gospels to gospel wildcard names and KJS antimentions" do
      entries = described_class.phrase_entries_for("fishermen_gospels")
      expect(entries.map { |entry| entry[:phrase] }).to eq(
        %w[Peter* Thomas* Nathanael* James* John*] + [
          Inamen::FishermenGospelsKjs.james_exclude_phrase,
          Inamen::FishermenGospelsKjs.john_exclude_phrase
        ]
      )
      expect(entries.last(2).map { |entry| entry[:exclude] }).to eq([true, true])
    end

    it "omits bulky antimentions from fishermen feature links" do
      entries = described_class.phrase_entries_for_link("fishermen_gospels")
      expect(entries.map { |entry| entry[:phrase] }).to eq(%w[Peter* Thomas* Nathanael* James* John*])
      expect(entries.none? { |entry| entry[:exclude] }).to be(true)
    end

    it "hydrates and compacts fishermen search phrases for session storage" do
      include_only = {
        "0" => { "phrase" => "Peter*" },
        "1" => { "phrase" => "Thomas*" }
      }
      full = described_class.search_phrases_hash_for("fishermen_gospels", raw: include_only)
      expect(full.keys).to eq(%w[0 1 2 3 4 5 6])
      expect(full["5"]["exclude"]).to eq("1")

      compact = described_class.compact_search_phrases_for_session("fishermen_gospels", full)
      expect(compact.keys).to eq(%w[0 1 2 3 4])
      expect(compact.values.sum { |row| row["phrase"].bytesize }).to be < 200
    end

    it "strips query_terms from session-bound discover query for fishermen_gospels" do
      bulky_terms = "Peter*\nThomas*\n" + ("x" * 5000)
      query = {
        edition: "kjv_normalized",
        mode: "word_count",
        from_feature: "fishermen_gospels",
        query_terms: bulky_terms,
        search_phrases: { "0" => { "phrase" => "Peter*" } }
      }
      compact = described_class.compact_discover_query_for_session("fishermen_gospels", query)
      expect(compact).not_to have_key(:query_terms)
      expect(compact[:search_phrases].keys).to eq(%w[0])
      expect(compact[:query_terms]).to be_nil
    end

    it "preserves edited fishermen antimentions instead of rehydrating the KJS preset" do
      preset = described_class.send(:preset_search_phrases_hash, "fishermen_gospels")
      edited = preset.dup
      edited["6"] = {
        "phrase" => "ANTIMENTIONS OF JOHN (THE APOSTLE, SON OF ZEBEDEE) | John the Baptist",
        "exclude" => "1"
      }

      expect(described_class.fishermen_phrases_customized?("fishermen_gospels", edited)).to be(true)
      hydrated = described_class.search_phrases_hash_for("fishermen_gospels", raw: edited)
      expect(hydrated["6"]["phrase"]).to eq(edited["6"]["phrase"])
      expect(hydrated["6"]["phrase"]).not_to eq(preset["6"]["phrase"])

      compact = described_class.compact_search_phrases_for_session("fishermen_gospels", edited)
      expect(compact["6"]["phrase"]).to eq(edited["6"]["phrase"])
    end

    it "treats disabled fishermen antimentions as customized for session storage" do
      preset = described_class.send(:preset_search_phrases_hash, "fishermen_gospels")
      disabled = preset.dup
      disabled["5"] = disabled["5"].merge("disabled" => "1")
      disabled["6"] = disabled["6"].merge("disabled" => "1")

      expect(described_class.fishermen_phrases_customized?("fishermen_gospels", disabled)).to be(true)
      compact = described_class.compact_search_phrases_for_session("fishermen_gospels", disabled)
      expect(compact["5"]["disabled"]).to eq("1")
      expect(compact["6"]["disabled"]).to eq("1")
    end

    it "does not rehydrate preset excludes when merge_preset_excludes is false" do
      raw = { "0" => { "phrase" => "Peter*" } }
      hydrated = described_class.search_phrases_hash_for(
        "fishermen_gospels",
        raw: raw,
        merge_preset_excludes: false
      )
      expect(hydrated).to eq({ "0" => { "phrase" => "Peter*" } })
    end

    it "rehydrates preset excludes for fishermen feature-link includes" do
      raw = {
        "0" => { "phrase" => "Peter*" },
        "1" => { "phrase" => "Thomas*" },
        "2" => { "phrase" => "Nathanael*" },
        "3" => { "phrase" => "James*" },
        "4" => { "phrase" => "John*" }
      }
      expect(described_class.fishermen_preset_includes?(raw)).to be(true)
      hydrated = described_class.search_phrases_hash_for("fishermen_gospels", raw: raw, merge_preset_excludes: true)
      expect(hydrated.keys).to eq(%w[0 1 2 3 4 5 6])
      expect(hydrated["5"]["exclude"]).to eq("1")
      expect(hydrated["6"]["exclude"]).to eq("1")
    end
  end

  describe ".resolve_from_feature" do
    it "drops fishermen_gospels when James* and John* are not included" do
      expect(described_class.resolve_from_feature("fishermen_gospels", query_terms: "Peter*")).to be_nil
      expect(described_class.resolve_from_feature("fishermen_gospels", query_terms: "Peter*\nThomas*")).to be_nil
    end

    it "keeps fishermen_gospels when James* or John* are included" do
      expect(described_class.resolve_from_feature("fishermen_gospels", query_terms: "James*")).to eq("fishermen_gospels")
      expect(described_class.resolve_from_feature("fishermen_gospels", query_terms: "James* | John*")).to eq("fishermen_gospels")
    end

    it "keeps other feature presets" do
      expect(described_class.resolve_from_feature("amen_77", query_terms: "Amen|cs")).to eq("amen_77")
    end
  end

  describe ".selection_for" do
    it "uses genesis and revelation verse text for in_amen_genesis_revelation" do
      selection = described_class.selection_for("in_amen_genesis_revelation")
      expect(selection.books).to eq(%w[Genesis Revelation])
      expect(selection.colophons).to be(false)
      expect(selection.superscriptions).to be(false)
    end

    it "uses scannable scope for peter_verses" do
      selection = described_class.selection_for("peter_verses")
      expect(selection.colophons).to be(true)
      expect(selection.superscriptions).to be(true)
      expect(selection.books).to eq(Inamen::BookCategories.all_books)
      expect(described_class.selection_query_for("peter_verses")).to eq(
        submitted: "1",
        colophons: "1",
        superscriptions: "1",
        all_books: "1"
      )
    end

    it "uses gospels for fishermen_gospels" do
      selection = described_class.selection_for("fishermen_gospels")
      expect(selection.books).to eq(Inamen::BookCategories.books_for_category(:nt, :gospels))
    end
  end

  describe ".fishermen_exclusions_from_query_terms" do
    it "does not apply John defaults when only James exclude rows are present" do
      james_line = "#{Inamen::FishermenGospelsKjs.james_exclude_phrase}|exclude"
      exclusions = described_class.fishermen_exclusions_from_query_terms("James*\n#{james_line}")
      expect(exclusions[:james]).not_to be_empty
      expect(exclusions[:john]).to eq([])
    end

    it "skips disabled John antimentions" do
      john_line = "#{Inamen::FishermenGospelsKjs.john_exclude_phrase}|exclude|disabled"
      exclusions = described_class.fishermen_exclusions_from_query_terms("John*\n#{john_line}")
      expect(exclusions[:john]).to eq([])
    end
  end

  describe ".search_phrases_from_post" do
    it "applies disabled flags to hydrated John antimentions" do
      preset = described_class.send(:preset_search_phrases_hash, "fishermen_gospels")
      posted = preset.each_with_object({}) do |(idx, row), compact|
        next if row["exclude"] == "1"

        compact[idx] = row
      end
      posted["6"] = preset["6"].merge("disabled" => "1")

      merged = described_class.search_phrases_from_post("fishermen_gospels", posted)
      expect(merged["6"]["disabled"]).to eq("1")
      expect(merged["5"]["exclude"]).to eq("1")
      expect(merged["5"]["disabled"]).to be_nil

      query_terms = merged.sort_by { |key, _| key.to_i }.map do |_, row|
        line = row["phrase"]
        line += "|exclude" if row["exclude"] == "1"
        line += "|disabled" if row["disabled"] == "1"
        line
      end.join("\n")
      exclusions = described_class.fishermen_exclusions_from_query_terms(query_terms)
      expect(exclusions[:john]).to eq([])
      expect(exclusions[:james]).not_to be_empty
    end
  end

  describe ".adjust_verse_result!" do
    let(:lines) { Inamen::KjvEditions.read_lines(Inamen::KjvEditions::EDITIONS["kjv_normalized"]) }
    let(:db_path) { Inamen::CorpusPublisher.prebuilt_path("kjv_normalized") }
    let(:db) { Inamen::CorpusStore.open(db_path) }
    let(:edition) do
      instance_double(
        "EditionContext",
        db: db,
        word_stream_index: nil,
        edition_id: "kjv_normalized",
        checksum_prefix: "test"
      )
    end

    after { db.close }

    it "limits paul_verses to verse-text rows for the verse summary" do
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      selection = described_class.selection_for("paul_verses")
      terms = Inamen::TokenQuery.parse_terms("Paul")
      result = Inamen::VerseMatchQuery.scan(db, terms: terms, search_selection: selection)
      expect(result.summary.verses).to eq(154)

      adjusted = described_class.adjust_verse_result!("paul_verses", result)
      expect(adjusted.summary.verses).to eq(153)
      expect(adjusted.summary.occurrences).to eq(157)
      expect(adjusted.verses.map(&:bucket).uniq).to eq([Inamen::CorpusStore::BUCKET_VERSE_TEXT])
    end
  end

  describe ".adjust_rows!" do
    let(:lines) { Inamen::KjvEditions.read_lines(Inamen::KjvEditions::EDITIONS["kjv_normalized"]) }
    let(:db_path) { Inamen::CorpusPublisher.prebuilt_path("kjv_normalized") }
    let(:db) { Inamen::CorpusStore.open(db_path) }
    let(:edition) do
      instance_double(
        "EditionContext",
        db: db,
        lines: lines,
        word_stream_index: nil,
        edition_id: "kjv_normalized",
        checksum_prefix: "test"
      )
    end

    after { db.close }

    it "subtracts antimention verses for jesus_mentions" do
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      selection = described_class.selection_for("jesus_mentions")
      query_terms = "#{described_class::JESUS_PHRASE}|cs"
      rows = Inamen::TokenQuery.scan(
        db,
        terms: Inamen::TokenQuery.parse_terms(query_terms),
        search_selection: selection
      )
      raw_total = rows.sum(&:count)

      adjusted = described_class.adjust_rows!(
        "jesus_mentions",
        edition,
        rows,
        search_selection: selection,
        query_terms: query_terms
      )

      expect(raw_total).to be >= 980
      expect(adjusted.sum(&:count)).to eq(980)
    end

    it "returns seven fishermen rows with antimention exclude counts" do
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      selection = described_class.selection_for("fishermen_gospels")
      query_terms = described_class.phrase_entries_for("fishermen_gospels").map do |entry|
        line = entry[:phrase]
        line += "|cs" if entry[:case_sensitive]
        line += "|exclude" if entry[:exclude]
        line
      end.join("\n")
      include_terms = Inamen::TokenQuery.parse_terms(
        query_terms.each_line.filter_map do |line|
          attrs = Inamen::TokenPattern.parse_query_line(line)
          next if attrs.nil? || attrs[:exclude]

          line.strip
        end.join("\n")
      )
      rows = Inamen::TokenQuery.scan(db, terms: include_terms, search_selection: selection)
      adjusted = described_class.adjust_rows!(
        "fishermen_gospels",
        edition,
        rows,
        search_selection: selection,
        query_terms: query_terms
      )

      expect(adjusted.size).to eq(7)
      expect(adjusted.count(&:exclude)).to eq(2)
      james_row = adjusted.find { |row| row.pattern == "James*" }
      john_row = adjusted.find { |row| row.pattern == "John*" }
      james_exclude = adjusted.find { |row| row.exclude && row.pattern.start_with?("ANTIMENTIONS OF JAMES") }
      john_exclude = adjusted.find { |row| row.exclude && row.pattern.start_with?("ANTIMENTIONS OF JOHN") }
      expect(james_row.count).to eq(29)
      expect(john_row.count).to eq(103)
      expect(james_row.spellings.values.sum).to eq(james_row.count)
      expect(john_row.spellings.values.sum).to eq(john_row.count)
      expect(john_row.spellings.keys).to include("John")
      expect(john_row.spellings.keys.any? { |raw| raw.include?("\u{2019}") || raw.include?("'") }).to be(true)
      expect(james_exclude.count).to eq(10)
      expect(john_exclude.count).to eq(83)
      total = adjusted.sum { |row| row.exclude ? -row.count : row.count }
      expect(total).to eq(153)
    end

    it "omits disabled fishermen antimentions from totals" do
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      selection = described_class.selection_for("fishermen_gospels")
      query_terms = described_class.phrase_entries_for("fishermen_gospels").map do |entry|
        line = entry[:phrase]
        line += "|cs" if entry[:case_sensitive]
        line += "|exclude" if entry[:exclude]
        line += "|disabled" if entry[:exclude]
        line
      end.join("\n")
      include_terms = Inamen::TokenQuery.parse_terms(
        query_terms.each_line.filter_map do |line|
          attrs = Inamen::TokenPattern.parse_query_line(line)
          next if attrs.nil? || attrs[:exclude] || attrs[:disabled]

          line.strip
        end.join("\n")
      )
      rows = Inamen::TokenQuery.scan(db, terms: include_terms, search_selection: selection)
      adjusted = described_class.adjust_rows!(
        "fishermen_gospels",
        edition,
        rows,
        search_selection: selection,
        query_terms: query_terms
      )

      expect(adjusted.count(&:exclude)).to eq(0)
      total = adjusted.sum { |row| row.exclude ? -row.count : row.count }
      expect(total).to eq(246)
    end

    it "omits only disabled John fishermen antimentions from totals" do
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      selection = described_class.selection_for("fishermen_gospels")
      query_terms = described_class.phrase_entries_for("fishermen_gospels").map do |entry|
        line = entry[:phrase]
        line += "|cs" if entry[:case_sensitive]
        line += "|exclude" if entry[:exclude]
        line += "|disabled" if entry[:exclude] && entry[:phrase].start_with?("ANTIMENTIONS OF JOHN")
        line
      end.join("\n")
      include_terms = Inamen::TokenQuery.parse_terms(
        query_terms.each_line.filter_map do |line|
          attrs = Inamen::TokenPattern.parse_query_line(line)
          next if attrs.nil? || attrs[:exclude] || attrs[:disabled]

          line.strip
        end.join("\n")
      )
      rows = Inamen::TokenQuery.scan(db, terms: include_terms, search_selection: selection)
      adjusted = described_class.adjust_rows!(
        "fishermen_gospels",
        edition,
        rows,
        search_selection: selection,
        query_terms: query_terms
      )

      expect(adjusted.count(&:exclude)).to eq(1)
      john_exclude = adjusted.find { |row| row.exclude && row.pattern.start_with?("ANTIMENTIONS OF JOHN") }
      expect(john_exclude).to be_nil
      total = adjusted.sum { |row| row.exclude ? -row.count : row.count }
      expect(total).to eq(236)
    end

    it "supports combined James* | John* include row" do
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      selection = described_class.selection_for("fishermen_gospels")
      preset = described_class.send(:preset_search_phrases_hash, "fishermen_gospels")
      custom = {
        "0" => preset["0"],
        "1" => preset["1"],
        "2" => preset["2"],
        "3" => { "phrase" => "James* | John*" },
        "4" => preset["5"],
        "5" => preset["6"]
      }
      query_terms = custom.sort_by { |key, _| key.to_i }.map do |_, row|
        line = row["phrase"]
        line += "|exclude" if row["exclude"] == "1"
        line
      end.join("\n")
      include_terms = Inamen::TokenQuery.parse_terms(
        query_terms.each_line.filter_map do |line|
          attrs = Inamen::TokenPattern.parse_query_line(line)
          next if attrs.nil? || attrs[:exclude]

          line.strip
        end.join("\n")
      )
      rows = Inamen::TokenQuery.scan(db, terms: include_terms, search_selection: selection)
      adjusted = described_class.adjust_rows!(
        "fishermen_gospels",
        edition,
        rows,
        search_selection: selection,
        query_terms: query_terms
      )
      combined = adjusted.find { |row| row.pattern == "James* | John*" }
      expect(combined).not_to be_nil
      expect(combined.count).to eq(132)
      total = adjusted.sum { |row| row.exclude ? -row.count : row.count }
      expect(total).to eq(153)
    end

    it "uses edited antimentions when computing fishermen totals" do
      skip "corpus missing" unless File.file?(db_path) && File.size(db_path) > 1_000_000

      selection = described_class.selection_for("fishermen_gospels")
      preset = described_class.send(:preset_search_phrases_hash, "fishermen_gospels")
      edited = preset.dup
      edited["6"] = {
        "phrase" => "ANTIMENTIONS OF JOHN (THE APOSTLE, SON OF ZEBEDEE) | John the Baptist",
        "exclude" => "1"
      }
      query_terms = edited.sort_by { |key, _| key.to_i }.map do |_, row|
        line = row["phrase"]
        line += "|exclude" if row["exclude"] == "1"
        line
      end.join("\n")
      include_terms = Inamen::TokenQuery.parse_terms(
        query_terms.each_line.filter_map do |line|
          attrs = Inamen::TokenPattern.parse_query_line(line)
          next if attrs.nil? || attrs[:exclude]

          line.strip
        end.join("\n")
      )
      rows = Inamen::TokenQuery.scan(db, terms: include_terms, search_selection: selection)
      adjusted = described_class.adjust_rows!(
        "fishermen_gospels",
        edition,
        rows,
        search_selection: selection,
        query_terms: query_terms
      )
      total = adjusted.sum { |row| row.exclude ? -row.count : row.count }
      expect(total).not_to eq(153)
      expect(total).to be > 153
    end
  end
end
