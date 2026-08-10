# frozen_string_literal: true

require "csv"
require "fileutils"
require "time"

begin
  require "unicode/name"
rescue LoadError
  nil
end

module Inamen
    # CSV-backed hierarchical statistics for an edition's source file and verse corpus.
    module FileStatsExplorer
    CACHE_VERSION = "12"

    Node = Struct.new(
      :node_id, :parent_id, :level, :label, :testament, :book, :chapter, :verse,
      :word_count, :number_count, :division_count, :character_count, :letter_count, :digit_count, :other_count,
      keyword_init: true
    )
    Category = Struct.new(:node_id, :category, :subcategory, :count, keyword_init: true)
    Character = Struct.new(:node_id, :category, :char, :codepoint, :name, :count, keyword_init: true)
    Result = Struct.new(:edition_id, :nodes, :categories, :characters, :nodes_by_parent, keyword_init: true) do
      def root
        nodes.find { |node| node.parent_id.to_s.empty? }
      end

      def children_of(node_id)
        nodes_by_parent.fetch(node_id.to_s, [])
      end

      def categories_for(node_id)
        @categories_by_node ||= categories.group_by(&:node_id)
        @categories_by_node.fetch(node_id.to_s, [])
      end

      def characters_for(node_id)
        @characters_by_node ||= characters.group_by(&:node_id)
        @characters_by_node.fetch(node_id.to_s, [])
      end

      def character_breakdown_for(node_id)
        FileStatsExplorer.character_breakdown_for(edition_id, node_id.to_s)
      end
    end

    NODE_HEADERS = %w[
      node_id parent_id level label testament book chapter verse
      word_count number_count division_count character_count letter_count digit_count other_count
    ].freeze
    CATEGORY_HEADERS = %w[node_id category subcategory count].freeze
    CHARACTER_HEADERS = %w[node_id category char codepoint name count].freeze
    CHARACTER_INDEX_HEADERS = %w[node_id offset line_count].freeze
    MANIFEST_HEADERS = %w[key value].freeze

    VOWELS = "aeiouаеёиоуыэюяαεηιουω".chars.freeze

    module_function

    def cache_dir(edition_id)
      File.join(FileStatsPublisher.prebuilt_root, edition_id.to_s)
    end

    def resolve(edition_id, checksum:, chapter_index:, lines: nil, source_text: nil, force: false)
      if force || !cache_current?(edition_id, checksum)
        build_cache!(edition_id, checksum:, chapter_index:, lines:, source_text:, force:)
      end
      load_cache(edition_id)
    end

    def build_cache!(edition_id, checksum:, chapter_index:, lines: nil, source_text: nil, force: false)
      dir = cache_dir(edition_id)
      return dir if !force && cache_current?(edition_id, checksum)

      FileUtils.mkdir_p(dir)
      nodes, char_counts_by_node = build_nodes_and_char_counts(edition_id, chapter_index, lines, source_text)
      root_id = node_id(edition_id, "edition")
      categories = build_categories(char_counts_by_node, root_id:)
      characters = build_characters(char_counts_by_node, root_id:)

      write_manifest(dir, edition_id, checksum)
      write_nodes(File.join(dir, "structure_nodes.csv"), nodes)
      write_categories(File.join(dir, "character_categories.csv"), categories)
      write_characters(File.join(dir, "characters.csv"), characters)
      write_node_characters(dir, char_counts_by_node)
      dir
    end

    def load_cache(edition_id)
      dir = cache_dir(edition_id)
      nodes = order_nodes(read_nodes(File.join(dir, "structure_nodes.csv")))
      categories = read_categories(File.join(dir, "character_categories.csv"))
      characters = read_characters(File.join(dir, "characters.csv"))
      Result.new(
        edition_id: edition_id,
        nodes: nodes,
        categories: categories,
        characters: characters,
        nodes_by_parent: nodes.group_by { |node| node.parent_id.to_s }
      )
    end

    def cache_current?(edition_id, checksum)
      manifest = manifest_for(edition_id)
      manifest["cache_version"] == CACHE_VERSION &&
        manifest["checksum"] == checksum.to_s &&
        File.file?(File.join(cache_dir(edition_id), "structure_nodes.csv")) &&
        File.file?(File.join(cache_dir(edition_id), "character_categories.csv")) &&
        File.file?(File.join(cache_dir(edition_id), "characters.csv")) &&
        File.file?(File.join(cache_dir(edition_id), "node_characters.csv")) &&
        File.file?(File.join(cache_dir(edition_id), "node_character_index.csv"))
    end

    def character_breakdown_for(edition_id, node_id)
      rows = read_node_characters(edition_id, node_id)
      {
        categories: build_categories({ node_id => rows.to_h { |row| [row.char, row.count] } }, root_id: node_id),
        characters: rows
      }
    end

    def build_nodes_and_char_counts(edition_id, chapter_index, lines = nil, source_text = nil)
      return build_nodes_from_events(edition_id, lines, source_text) if lines

      build_nodes_from_chapter_index(edition_id, chapter_index, source_text)
    end

    def build_nodes_from_events(edition_id, lines, source_text = nil)
      nodes_by_id = {}
      char_counts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @last_assigned_line_index = 0

      root_id = node_id(edition_id, "edition")
      ensure_node(nodes_by_id, root_id, nil, "edition", edition_id.to_s, nil, nil, nil, nil)
      source_id = node_id(edition_id, "source")
      ensure_node(nodes_by_id, source_id, root_id, "source", "Source text outside canon", nil, nil, nil, nil)
      @file_spacing_node_id = node_id(edition_id, "file_spacing")
      ensure_node(nodes_by_id, @file_spacing_node_id, root_id, "source", "File spacing outside parsed text", nil, nil, nil, nil)

      physical_lines = physical_lines_for(source_text, lines)
      labels = BookStatsReport.book_label_at_each_index(lines)
      state = { book: nil, chapter: nil, verse: nil }
      last_leaf_id = nil
      event_lines = {}

      KjvLineParser.each_event(lines) do |event|
        event_lines[event.lineno] = true
        assign_gap_lines!(nodes_by_id, char_counts, physical_lines, last_leaf_id || source_id, event.lineno)

        book = labels[event.lineno - 1]
        if book != state[:book]
          state[:book] = book
          state[:chapter] = state[:verse] = nil
        end

        prev_chapter = state[:chapter]
        ChapterReport.send(:advance_chapter!, state, event, book)
        state[:verse] = nil if state[:chapter] != prev_chapter && state[:chapter]

        update_verse_state!(state, event)

        line_text = physical_lines.fetch(event.lineno - 1, event.raw.to_s)
        title_assignments = split_book_title_assignments(
          edition_id, nodes_by_id, root_id, source_id, event, book, labels, state, physical_lines, line_text
        )
        if title_assignments
          title_assignments.each do |target_id, text|
            add_text_to_node!(nodes_by_id.fetch(target_id), text, char_counts[target_id])
            last_leaf_id = target_id
          end
          next
        end

        target_id = node_for_event!(edition_id, nodes_by_id, root_id, source_id, event, book, state, physical_lines)
        if event.kind == KjvParseEvent::KIND_PSALM_119_DIVISION
          add_stanza_text_to_node!(
            nodes_by_id.fetch(target_id),
            line_text,
            char_counts[target_id],
            event.totals_delta.fetch(:text_words, 0),
            event.totals_delta.fetch(:psalm_119_division_words, 0)
          )
        else
          add_text_to_node!(nodes_by_id.fetch(target_id), line_text, char_counts[target_id])
        end
        last_leaf_id = target_id
      end

      assign_trailing_lines!(nodes_by_id, char_counts, physical_lines, event_lines, last_leaf_id || source_id)
      aggregate_all_nodes!(nodes_by_id, char_counts)

      [order_nodes(nodes_by_id.values), char_counts]
    end

    def build_nodes_from_chapter_index(edition_id, chapter_index, source_text = nil)
      nodes_by_id = {}
      char_counts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      corpus_text = +""

      root_id = node_id(edition_id, "edition")
      ensure_node(nodes_by_id, root_id, nil, "edition", edition_id.to_s, nil, nil, nil, nil)

      chapter_index.each do |book, chapters|
        book_id = ensure_book_path!(edition_id, nodes_by_id, root_id, book)
        chapters.sort.each do |chapter, verses|
          chapter_id = ensure_chapter_node!(edition_id, nodes_by_id, book_id, book, chapter)
          verses.sort.each do |verse, text|
            verse_id = node_id(edition_id, "verse", book, chapter, verse)
            node = ensure_node(nodes_by_id, verse_id, chapter_id, "verse", "Verse #{verse}", BibleBooks.testament_for(book), book, chapter, verse)
            add_text_to_node!(node, text, char_counts[verse_id])
            corpus_text << text.to_s
          end
        end
      end

      aggregate_all_nodes!(nodes_by_id, char_counts)
      if source_text.to_s.empty?
        char_counts[root_id] = count_characters(corpus_text)
      else
        char_counts[root_id] = count_characters(source_text)
        assign_stats!(nodes_by_id.fetch(root_id), stats_for_text(source_text))
      end

      [order_nodes(nodes_by_id.values), char_counts]
    end

    def add_title_text_nodes!(edition_id, nodes_by_id, char_counts, root_id, source_text)
      return if source_text.to_s.empty?

      full_stats = stats_for_text(source_text)
      corpus_node_ids = nodes_by_id.values.select { |node| node.level == "testament" }.map(&:node_id)
      title_segments = source_title_segments(source_text)

      title_id = node_id(edition_id, "title")
      ensure_node(nodes_by_id, title_id, root_id, "title", "Source text outside verses", nil, nil, nil, nil)

      title_segments.each do |key, text|
        next if text.empty?

        part_id = node_id(edition_id, "title", key)
        node = ensure_node(nodes_by_id, part_id, title_id, "title_part", title_part_label(key), nil, nil, nil, nil)
        apply_leaf_counts!(node, text)
      end

      residual_stats = subtract_stats(
        full_stats,
        *corpus_node_ids.map { |id| stats_for_node(nodes_by_id.fetch(id)) },
        *title_segments.values.map { |text| stats_for_text(text) }
      )

      if residual_stats.values.any?(&:positive?)
        other_id = node_id(edition_id, "title", "other")
        other = ensure_node(nodes_by_id, other_id, title_id, "title_part", "Book/chapter/verse markers and spacing", nil, nil, nil, nil)
        assign_stats!(other, residual_stats)
      end

      nodes_by_id.values.select { |node| node.parent_id == title_id }.each do |node|
        aggregate_node!(nodes_by_id[title_id], node)
      end
    end

    def physical_lines_for(source_text, lines)
      source = source_text.to_s
      return source.each_line.to_a unless source.empty?

      Array(lines).map.with_index { |line, index| "#{line}#{index == lines.length - 1 ? "" : "\n"}" }
    end

    def assign_gap_lines!(nodes_by_id, char_counts, physical_lines, target_id, next_lineno)
      start_index = @last_assigned_line_index.to_i
      end_index = next_lineno - 2
      (start_index..end_index).each do |index|
        line = physical_lines[index]
        next unless line

        line_target_id = spacing_target_id(nodes_by_id, target_id, line)
        add_text_to_node!(nodes_by_id.fetch(line_target_id), line, char_counts[line_target_id])
      end
      @last_assigned_line_index = next_lineno
    end

    def assign_trailing_lines!(nodes_by_id, char_counts, physical_lines, event_lines, target_id)
      start_index = @last_assigned_line_index.to_i
      (start_index...physical_lines.length).each do |index|
        next if event_lines[index + 1]

        line = physical_lines[index]
        line_target_id = spacing_target_id(nodes_by_id, target_id, line)
        add_text_to_node!(nodes_by_id.fetch(line_target_id), line, char_counts[line_target_id])
      end
      @last_assigned_line_index = nil
    end

    def update_verse_state!(state, event)
      d = event.totals_delta
      s = event.stripped
      case event.kind
      when KjvParseEvent::KIND_NUMBERED_LINE, KjvParseEvent::KIND_VERSE_AFTER_PSALM_HEADING
        state[:verse] = nil if d[:chapter_numbers].to_i.positive?
        state[:verse] = KjvLineParser.verse_line_number(s) if d[:verse_numbers].to_i.positive?
      when KjvParseEvent::KIND_IMPLICIT_PSALM_OPENING
        state[:verse] = 1 if d[:implicit_psalm_verse_1].to_i.positive? || d[:verse_numbers].to_i.positive?
      when KjvParseEvent::KIND_IMPLICIT_CHAPTER_OPENING
        state[:verse] = 1 if d[:implicit_chapter_verse_1].to_i.positive? || d[:verse_numbers].to_i.positive?
      when KjvParseEvent::KIND_SPLIT_VERSE_NUMBER
        state[:verse] = s.to_i
      end
    end

    def spacing_target_id(nodes_by_id, target_id, line)
      target = nodes_by_id.fetch(target_id)
      line.to_s.strip.empty? && target.level == "source_part" ? @file_spacing_node_id : target_id
    end

    def node_for_event!(edition_id, nodes_by_id, root_id, source_id, event, book, state, physical_lines)
      stripped = event.stripped

      return source_part_node!(edition_id, nodes_by_id, source_id, "bible_name", "Bible name") if bible_name_line?(stripped)
      return source_part_node!(edition_id, nodes_by_id, source_id, "version", "Version") if version_line?(stripped)

      if nt_header_line?(stripped, KjvLine.strip(physical_lines[event.lineno]))
        nt_id = ensure_testament_node!(edition_id, nodes_by_id, root_id, "NT")
        return ensure_node(nodes_by_id, node_id(edition_id, "nt_header"), nt_id, "header", "New Testament header", "NT", nil, nil, nil).node_id
      end

      return source_id unless book && BibleBooks.testament_for(book)

      book_id = ensure_book_path!(edition_id, nodes_by_id, root_id, book)
      chapter = state[:chapter]
      chapter_id = chapter ? ensure_chapter_node!(edition_id, nodes_by_id, book_id, book, chapter) : book_id

      case event.kind
      when KjvParseEvent::KIND_BOOK_TITLE
        ensure_node(nodes_by_id, node_id(edition_id, "book_name", book), book_id, "book_part", "Book name", BibleBooks.testament_for(book), book, nil, nil).node_id
      when KjvParseEvent::KIND_CHAPTER_TITLE, KjvParseEvent::KIND_PSALM_TITLE
        label = book == "Psalms" ? "Psalm header" : "Chapter header"
        ensure_node(nodes_by_id, node_id(edition_id, "chapter_header", book, chapter), chapter_id, "chapter_part", label, BibleBooks.testament_for(book), book, chapter, nil).node_id
      when KjvParseEvent::KIND_PSALM_HEADING
        ensure_node(nodes_by_id, node_id(edition_id, "superscription", book, chapter || 0), chapter_id, "chapter_part", "Superscription", BibleBooks.testament_for(book), book, chapter, nil).node_id
      when KjvParseEvent::KIND_PSALM_119_DIVISION
        ensure_node(nodes_by_id, node_id(edition_id, "psalm_119_divisions", book, chapter || 119), chapter_id, "chapter_part", "Hebrew letters", BibleBooks.testament_for(book), book, chapter, nil).node_id
      else
        if CorpusIndexer.send(:colophon_event?, event)
          return ensure_node(nodes_by_id, node_id(edition_id, "colophons", book, chapter || 0), chapter_id, "chapter_part", "Colophons", BibleBooks.testament_for(book), book, chapter, nil).node_id
        end

        verse = state[:verse]
        return chapter_id unless chapter && verse

        ensure_node(nodes_by_id, node_id(edition_id, "verse", book, chapter, verse), chapter_id, "verse", "Verse #{verse}", BibleBooks.testament_for(book), book, chapter, verse).node_id
      end
    end

    def split_book_title_assignments(edition_id, nodes_by_id, root_id, source_id, event, book, labels, state, physical_lines, line_text)
      stripped = event.stripped
      return nil if bible_name_line?(stripped) || version_line?(stripped)
      return nil if nt_header_line?(stripped, KjvLine.strip(physical_lines[event.lineno]))
      return nil unless LineClassifier.classify(stripped) == :book_title

      upcoming_book = upcoming_canonical_book(labels, event.lineno - 1, book)
      return nil unless upcoming_book

      target_id = book_title_node!(edition_id, nodes_by_id, root_id, upcoming_book)

      if BibleBooks.testament_for(book).nil?
        return [[target_id, line_text]]
      end

      return [[target_id, line_text]] if stripped == "THE GOSPEL ACCORDING TO" && !preceded_by_nt_header?(physical_lines, event.lineno)
      return nil unless stripped == "THE GOSPEL ACCORDING TO"

      connector_target = node_for_event!(edition_id, nodes_by_id, root_id, source_id, event, book, state, physical_lines)
      newline = line_text.end_with?("\n") ? "\n" : ""
      [[connector_target, "THE TO#{newline}"], [target_id, "GOSPEL ACCORDING#{newline}"]]
    end

    def upcoming_canonical_book(labels, index, current_book)
      labels[(index + 1)..]&.find do |label|
        label != current_book && BibleBooks.testament_for(label)
      end
    end

    def book_title_node!(edition_id, nodes_by_id, root_id, book)
      book_id = ensure_book_path!(edition_id, nodes_by_id, root_id, book)
      ensure_node(nodes_by_id, node_id(edition_id, "book_title", book), book_id, "book_part", "Book title", BibleBooks.testament_for(book), book, nil, nil).node_id
    end

    def preceded_by_nt_header?(physical_lines, lineno)
      start_index = [lineno - 8, 0].max
      physical_lines[start_index...(lineno - 1)].any? do |line|
        nt_header_line?(KjvLine.strip(line), nil)
      end
    end

    def source_part_node!(edition_id, nodes_by_id, source_id, key, label)
      ensure_node(nodes_by_id, node_id(edition_id, "source", key), source_id, "source_part", label, nil, nil, nil, nil).node_id
    end

    def ensure_book_path!(edition_id, nodes_by_id, root_id, book)
      testament = BibleBooks.testament_for(book) || "edition"
      testament_id = ensure_testament_node!(edition_id, nodes_by_id, root_id, testament)
      category = book_category_for(book)
      category_id = node_id(edition_id, "category", testament, category.id)
      ensure_node(nodes_by_id, category_id, testament_id, "category", category.label, testament, nil, nil, nil)
      book_id = node_id(edition_id, "book", book)
      ensure_node(nodes_by_id, book_id, category_id, "book", book, testament, book, nil, nil)
      book_id
    end

    def ensure_testament_node!(edition_id, nodes_by_id, root_id, testament)
      testament_id = node_id(edition_id, "testament", testament)
      ensure_node(nodes_by_id, testament_id, root_id, "testament", testament_label(testament), testament, nil, nil, nil)
      testament_id
    end

    def ensure_chapter_node!(edition_id, nodes_by_id, book_id, book, chapter)
      testament = BibleBooks.testament_for(book)
      label = book == "Psalms" ? "Psalm #{chapter}" : "Chapter #{chapter}"
      chapter_id = node_id(edition_id, "chapter", book, chapter)
      ensure_node(nodes_by_id, chapter_id, book_id, "chapter", label, testament, book, chapter, nil)
      chapter_id
    end

    def book_category_for(book)
      testament = BibleBooks.testament_for(book)&.downcase&.to_sym
      Inamen::BookCategories.categories_for(testament).find { |category| category.books.include?(book) } ||
        Inamen::BookCategories::Category.new(id: :books, label: "Books", testament: testament, books: [book])
    end

    def add_text_to_node!(node, text, char_count_bucket)
      stats = stats_for_text(text)
      node.word_count += stats.fetch(:word_count)
      node.number_count += stats.fetch(:number_count)
      node.division_count += stats.fetch(:division_count)
      node.character_count += stats.fetch(:character_count)
      node.letter_count += stats.fetch(:letter_count)
      node.digit_count += stats.fetch(:digit_count)
      node.other_count += stats.fetch(:other_count)
      count_characters(text).each { |char, count| char_count_bucket[char] += count }
    end

    def add_stanza_text_to_node!(node, text, char_count_bucket, word_count, division_count)
      stats = stats_for_text(text)
      node.word_count += word_count
      node.division_count += division_count
      node.character_count += stats.fetch(:character_count)
      node.letter_count += stats.fetch(:letter_count)
      node.digit_count += stats.fetch(:digit_count)
      node.other_count += stats.fetch(:other_count)
      count_characters(text).each { |char, count| char_count_bucket[char] += count }
    end

    def aggregate_all_nodes!(nodes_by_id, char_counts)
      nodes_by_parent = nodes_by_id.values.group_by { |node| node.parent_id.to_s }
      aggregate_children!(nodes_by_id.values.find { |node| node.parent_id.nil? }, nodes_by_parent, char_counts)
    end

    def aggregate_children!(node, nodes_by_parent, char_counts)
      nodes_by_parent.fetch(node.node_id, []).each do |child|
        aggregate_children!(child, nodes_by_parent, char_counts)
        aggregate_node!(node, child)
        char_counts[child.node_id].each { |char, count| char_counts[node.node_id][char] += count }
      end
    end

    def ensure_node(nodes_by_id, id, parent_id, level, label, testament, book, chapter, verse)
      nodes_by_id[id] ||= Node.new(
        node_id: id,
        parent_id: parent_id,
        level: level,
        label: label,
        testament: testament,
        book: book,
        chapter: chapter,
        verse: verse,
        word_count: 0,
        number_count: 0,
        division_count: 0,
        character_count: 0,
        letter_count: 0,
        digit_count: 0,
        other_count: 0
      )
    end

    def apply_leaf_counts!(node, text)
      assign_stats!(node, stats_for_text(text))
    end

    def stats_for_text(text)
      tokens = Tokenizer.tokenize(text)
      {
        word_count: tokens.count { |token| !token.match?(/\A[0-9]+\z/) },
        number_count: tokens.count { |token| token.match?(/\A[0-9]+\z/) },
        division_count: 0,
        character_count: text.to_s.length,
        letter_count: text.to_s.each_char.count { |char| letter?(char) },
        digit_count: text.to_s.each_char.count { |char| char.match?(/\p{Nd}/) },
        other_count: text.to_s.each_char.count { |char| !letter?(char) && !char.match?(/\p{Nd}/) }
      }
    end

    def stats_for_node(node)
      {
        word_count: node.word_count,
        number_count: node.number_count,
        division_count: node.division_count,
        character_count: node.character_count,
        letter_count: node.letter_count,
        digit_count: node.digit_count,
        other_count: node.other_count
      }
    end

    def assign_stats!(node, stats)
      node.word_count = stats.fetch(:word_count)
      node.number_count = stats.fetch(:number_count)
      node.division_count = stats.fetch(:division_count)
      node.character_count = stats.fetch(:character_count)
      node.letter_count = stats.fetch(:letter_count)
      node.digit_count = stats.fetch(:digit_count)
      node.other_count = stats.fetch(:other_count)
    end

    def aggregate_node!(parent, child)
      parent.word_count += child.word_count
      parent.number_count += child.number_count
      parent.division_count += child.division_count
      parent.character_count += child.character_count
      parent.letter_count += child.letter_count
      parent.digit_count += child.digit_count
      parent.other_count += child.other_count
    end

    def count_characters(text)
      text.to_s.each_char.each_with_object(Hash.new(0)) { |char, counts| counts[char] += 1 }
    end

    def subtract_stats(stats, *deductions)
      deductions.each_with_object(stats.dup) do |deduction, result|
        result.keys.each { |key| result[key] -= deduction.fetch(key, 0) }
      end.transform_values { |value| [value, 0].max }
    end

    def source_title_segments(source_text)
      segments = {
        bible_name: +"",
        version: +"",
        nt_header: +""
      }

      lines = source_text.to_s.each_line.to_a
      lines.each_with_index do |line, index|
        stripped = KjvLine.strip(line)
        next if stripped.empty?

        if bible_name_line?(stripped)
          segments[:bible_name] << line
        elsif version_line?(stripped)
          segments[:version] << line
        elsif nt_header_line?(stripped, KjvLine.strip(lines[index + 1]))
          segments[:nt_header] << line
        end
      end

      segments
    end

    def bible_name_line?(stripped)
      stripped.match?(/\A(?:THE\s+)?HOLY BIBLE\z/i)
    end

    def version_line?(stripped)
      stripped.match?(/\A(?:AUTHORIZED\s+)?KING JAMES VERSION\z/i) ||
        stripped.match?(/\AAUTHORIZED VERSION\z/i)
    end

    def nt_header_line?(stripped, next_stripped)
      return true if stripped == "THE" && next_stripped == "NEW TESTAMENT"

      [
        "NEW TESTAMENT",
        "OF OUR LORD AND SAVIOR",
        "OF OUR LORD AND SAVIOUR",
        "JESUS CHRIST"
      ].include?(stripped)
    end

    def title_part_label(key)
      {
        bible_name: "Bible name",
        version: "Version",
        nt_header: "New Testament header"
      }.fetch(key, key.to_s)
    end

    def build_categories(char_counts_by_node, root_id:)
      char_counts_by_node.select { |node_id, _| node_id == root_id }.flat_map do |node_id, counts|
        category_counts = Hash.new(0)
        counts.each { |char, count| categories_for_char(char).each { |category| category_counts[category] += count } }
        category_counts.sort.map do |(category, subcategory), count|
          Category.new(node_id: node_id, category: category, subcategory: subcategory, count: count)
        end
      end
    end

    def build_characters(char_counts_by_node, root_id:)
      char_counts_by_node.select { |node_id, _| node_id == root_id }.flat_map do |node_id, counts|
        counts.sort_by { |char, _| char.ord }.map do |char, count|
          Character.new(
            node_id: node_id,
            category: top_category_for_char(char),
            char: char,
            codepoint: codepoint(char),
            name: readable_character_name(char),
            count: count
          )
        end
      end
    end

    def categories_for_char(char)
      if letter?(char)
        [["letters", "total"], ["letters", letter_kind(char)], ["letters", letter_case(char)]].uniq
      elsif char.match?(/\p{Nd}/)
        [["digits", "total"]]
      elsif char.match?(/\p{P}/)
        [["punctuation", "total"]]
      elsif char.match?(/\s/)
        [["whitespace", "total"], ["whitespace", whitespace_kind(char)]].uniq
      else
        [["other", "total"]]
      end
    end

    def top_category_for_char(char)
      return "letters" if letter?(char)
      return "digits" if char.match?(/\p{Nd}/)
      return "punctuation" if char.match?(/\p{P}/)
      return "whitespace" if char.match?(/\s/)

      "other"
    end

    def letter?(char)
      char.match?(/\p{L}/)
    end

    def letter_kind(char)
      return "small_caps" if small_cap?(char)

      normalized = char.unicode_normalize(:nfd).each_char.first&.downcase
      return "other_letters" if %w[æ œ].include?(normalized)
      return "vowels" if normalized && VOWELS.include?(normalized)
      return "consonants" if char.match?(/\p{L}/)

      "other_letters"
    end

    def letter_case(char)
      return "small_caps" if small_cap?(char)
      return "uppercase" if char == char.upcase && char != char.downcase
      return "lowercase" if char == char.downcase && char != char.upcase

      "other_letters"
    end

    def small_cap?(char)
      char.ord.between?(0x1D00, 0x1D7F) || char.ord.between?(0xA720, 0xA7FF)
    end

    def whitespace_kind(char)
      case char
      when " " then "space"
      when "\n" then "newline"
      when "\t" then "tab"
      when "\r" then "carriage_return"
      else "other_whitespace"
      end
    end

    def readable_character_name(char)
      case char
      when " " then "Space"
      when "\n" then "Newline"
      when "\t" then "Tab"
      when "\r" then "Carriage return"
      when "\u00B6" then "Paragraph mark"
      else
        return ascii_character_name(char) if char.ord < 128

        if defined?(Unicode::Name) && Unicode::Name.respond_to?(:of)
          Unicode::Name.of(char) || codepoint(char)
        else
          codepoint(char)
        end
      end
    end

    def ascii_character_name(char)
      if char.match?(/[A-Z]/)
        "Latin capital letter #{char}"
      elsif char.match?(/[a-z]/)
        "Latin small letter #{char}"
      elsif char.match?(/[0-9]/)
        "Digit #{char}"
      else
        {
          "!" => "Exclamation mark",
          '"' => "Quotation mark",
          "#" => "Number sign",
          "$" => "Dollar sign",
          "%" => "Percent sign",
          "&" => "Ampersand",
          "'" => "Apostrophe",
          "(" => "Left parenthesis",
          ")" => "Right parenthesis",
          "*" => "Asterisk",
          "+" => "Plus sign",
          "," => "Comma",
          "-" => "Hyphen-minus",
          "." => "Full stop",
          "/" => "Slash",
          ":" => "Colon",
          ";" => "Semicolon",
          "<" => "Less-than sign",
          "=" => "Equals sign",
          ">" => "Greater-than sign",
          "?" => "Question mark",
          "@" => "Commercial at",
          "[" => "Left square bracket",
          "\\" => "Backslash",
          "]" => "Right square bracket",
          "^" => "Circumflex accent",
          "_" => "Low line",
          "`" => "Grave accent",
          "{" => "Left curly bracket",
          "|" => "Vertical line",
          "}" => "Right curly bracket",
          "~" => "Tilde"
        }.fetch(char, codepoint(char))
      end
    end

    def codepoint(char)
      "U+#{char.ord.to_s(16).upcase.rjust(4, '0')}"
    end

    def node_id(edition_id, *parts)
      ([edition_id] + parts).compact.join(":")
    end

    def testament_label(testament)
      { "OT" => "Old Testament", "NT" => "New Testament", "AP" => "Apocrypha" }.fetch(testament, testament.to_s)
    end

    def order_nodes(nodes)
      order = {
        "edition" => 0,
        "source" => 1,
        "source_part" => 2,
        "title" => 1,
        "title_part" => 2,
        "testament" => 3,
        "header" => 4,
        "category" => 5,
        "book" => 6,
        "book_part" => 7,
        "chapter" => 8,
        "chapter_part" => 9,
        "verse" => 10
      }
      nodes.sort_by do |node|
        [
          order.fetch(node.level, 9),
          testament_sort_index(node),
          category_sort_index(node),
          title_sort_index(node),
          BibleBooks::ALL.index(node.book) || -1,
          node.chapter.to_i,
          node.verse.to_i,
          node.node_id
        ]
      end
    end

    def testament_sort_index(node)
      { "OT" => 0, "NT" => 1, "AP" => 2 }.fetch(node.testament.to_s, -1)
    end

    def category_sort_index(node)
      return 0 unless node.level == "category"

      Inamen::BookCategories.categories_for(node.testament.to_s.downcase.to_sym).index do |category|
        node.node_id.end_with?(":#{category.id}")
      end || 99
    end

    def title_sort_index(node)
      return 0 unless node.level == "title_part"

      {
        "Bible name" => 0,
        "Version" => 1,
        "New Testament header" => 2,
        "Book/chapter/verse markers and spacing" => 3,
        "Other title text" => 3
      }.fetch(node.label, 9)
    end

    def write_manifest(dir, edition_id, checksum)
      CSV.open(File.join(dir, "manifest.csv"), "w", write_headers: true, headers: MANIFEST_HEADERS) do |csv|
        csv << ["cache_version", CACHE_VERSION]
        csv << ["edition_id", edition_id]
        csv << ["checksum", checksum]
        csv << ["generated_at", Time.now.utc.iso8601]
      end
    end

    def write_nodes(path, nodes)
      CSV.open(path, "w", write_headers: true, headers: NODE_HEADERS) do |csv|
        nodes.each { |node| csv << NODE_HEADERS.map { |header| node.public_send(header) } }
      end
    end

    def write_categories(path, categories)
      CSV.open(path, "w", write_headers: true, headers: CATEGORY_HEADERS) do |csv|
        categories.each { |category| csv << CATEGORY_HEADERS.map { |header| category.public_send(header) } }
      end
    end

    def write_characters(path, characters)
      CSV.open(path, "w", write_headers: true, headers: CHARACTER_HEADERS) do |csv|
        characters.each { |char| csv << CHARACTER_HEADERS.map { |header| char.public_send(header) } }
      end
    end

    def write_node_characters(dir, char_counts_by_node)
      character_path = File.join(dir, "node_characters.csv")
      index_rows = []

      File.open(character_path, "wb") do |file|
        file.write(CSV.generate_line(CHARACTER_HEADERS))
        char_counts_by_node.sort.each do |node_id, counts|
          offset = file.pos
          line_count = 0
          counts.sort_by { |char, _| char.ord }.each do |char, count|
            point = codepoint(char)
            row = Character.new(
              node_id: node_id,
              category: top_category_for_char(char),
              char: point,
              codepoint: point,
              name: readable_character_name(char),
              count: count
            )
            file.write(CSV.generate_line(CHARACTER_HEADERS.map { |header| row.public_send(header) }))
            line_count += 1
          end
          index_rows << [node_id, offset, line_count]
        end
      end

      CSV.open(File.join(dir, "node_character_index.csv"), "w", write_headers: true, headers: CHARACTER_INDEX_HEADERS) do |csv|
        index_rows.each { |row| csv << row }
      end
    end

    def read_nodes(path)
      CSV.read(path, headers: true).map do |row|
        Node.new(
          node_id: row["node_id"],
          parent_id: blank_to_nil(row["parent_id"]),
          level: row["level"],
          label: row["label"],
          testament: blank_to_nil(row["testament"]),
          book: blank_to_nil(row["book"]),
          chapter: blank_to_nil(row["chapter"])&.to_i,
          verse: blank_to_nil(row["verse"])&.to_i,
          word_count: row["word_count"].to_i,
          number_count: row["number_count"].to_i,
          division_count: row["division_count"].to_i,
          character_count: row["character_count"].to_i,
          letter_count: row["letter_count"].to_i,
          digit_count: row["digit_count"].to_i,
          other_count: row["other_count"].to_i
        )
      end
    end

    def read_categories(path)
      CSV.read(path, headers: true).map do |row|
        Category.new(node_id: row["node_id"], category: row["category"], subcategory: row["subcategory"], count: row["count"].to_i)
      end
    end

    def read_characters(path)
      CSV.read(path, headers: true).map do |row|
        Character.new(
          node_id: row["node_id"], category: row["category"], char: row["char"],
          codepoint: row["codepoint"], name: row["name"], count: row["count"].to_i
        )
      end
    end

    def read_node_characters(edition_id, node_id)
      dir = cache_dir(edition_id)
      index_row = CSV.foreach(File.join(dir, "node_character_index.csv"), headers: true).find do |row|
        row["node_id"] == node_id
      end
      return [] unless index_row

      offset = index_row["offset"].to_i
      line_count = index_row["line_count"].to_i
      lines = []
      File.open(File.join(dir, "node_characters.csv"), "rb") do |file|
        file.seek(offset)
        line_count.times do
          line = file.gets
          lines << line.force_encoding("UTF-8") if line
        end
      end

      CSV.parse(lines.join, headers: CHARACTER_HEADERS).map do |row|
        point = row["codepoint"]
        Character.new(
          node_id: row["node_id"], category: row["category"], char: char_from_codepoint(point),
          codepoint: point, name: row["name"], count: row["count"].to_i
        )
      end
    end

    def char_from_codepoint(value)
      value.to_s.delete_prefix("U+").to_i(16).chr(Encoding::UTF_8)
    end

    def manifest_for(edition_id)
      path = File.join(cache_dir(edition_id), "manifest.csv")
      return {} unless File.file?(path)

      CSV.read(path, headers: true).to_h { |row| [row["key"], row["value"]] }
    end

    def blank_to_nil(value)
      text = value.to_s
      text.empty? ? nil : text
    end
  end
end
