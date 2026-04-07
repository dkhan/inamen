# frozen_string_literal: true

module Inamen
  # Per-book chapter/verse totals while parsing (same rules as CountingService.total_for_lines),
  # compared to standard KJV Protestant canon (1189 chapters, 31102 verses).
  module BookStatsReport
    CANON = [
      ["Genesis", 50, 1533], ["Exodus", 40, 1213], ["Leviticus", 27, 859], ["Numbers", 36, 1288],
      ["Deuteronomy", 34, 959], ["Joshua", 24, 658], ["Judges", 21, 618], ["Ruth", 4, 85],
      ["1 Samuel", 31, 810], ["2 Samuel", 24, 695], ["1 Kings", 22, 816], ["2 Kings", 25, 719],
      ["1 Chronicles", 29, 942], ["2 Chronicles", 36, 822], ["Ezra", 10, 280], ["Nehemiah", 13, 406],
      ["Esther", 10, 167], ["Job", 42, 1070], ["Psalms", 150, 2461], ["Proverbs", 31, 915],
      ["Ecclesiastes", 12, 222], ["Song of Solomon", 8, 117], ["Isaiah", 66, 1292],
      ["Jeremiah", 52, 1364], ["Lamentations", 5, 154], ["Ezekiel", 48, 1273], ["Daniel", 12, 357],
      ["Hosea", 14, 197], ["Joel", 3, 73], ["Amos", 9, 146], ["Obadiah", 1, 21], ["Jonah", 4, 48],
      ["Micah", 7, 105], ["Nahum", 3, 47], ["Habakkuk", 3, 56], ["Zephaniah", 3, 53],
      ["Haggai", 2, 38], ["Zechariah", 14, 211], ["Malachi", 4, 55], ["Matthew", 28, 1071],
      ["Mark", 16, 678], ["Luke", 24, 1151], ["John", 21, 879], ["Acts", 28, 1007],
      ["Romans", 16, 433], ["1 Corinthians", 16, 437], ["2 Corinthians", 13, 257],
      ["Galatians", 6, 149], ["Ephesians", 6, 155], ["Philippians", 4, 104], ["Colossians", 4, 95],
      ["1 Thessalonians", 5, 89], ["2 Thessalonians", 3, 47], ["1 Timothy", 6, 113],
      ["2 Timothy", 4, 83], ["Titus", 3, 46], ["Philemon", 1, 25], ["Hebrews", 13, 303],
      ["James", 5, 108], ["1 Peter", 5, 105], ["2 Peter", 3, 61], ["1 John", 5, 105],
      ["2 John", 1, 13], ["3 John", 1, 14], ["Jude", 1, 25], ["Revelation", 22, 404]
    ].freeze

    EXPECTED = CANON.to_h { |name, ch, vs| [name, { chapters: ch, verses: vs }] }.freeze

    def self.prev_strips(lines, idx, max)
      out = []
      j = idx - 1
      while j >= 0 && out.length < max
        t = lines[j].to_s.strip
        out << t unless t.empty?
        j -= 1
      end
      out
    end

    def self.prev_blob(lines, idx, max = 10)
      # Newest-first from +prev_strips+; reverse so title lines read in file order for substring checks.
      prev_strips(lines, idx, max).reverse.join(" ")
    end

    def self.prior_stripped(lines, idx)
      prev_strips(lines, idx, 1).first
    end

    # Returns new book name when +lines[i]+ starts a book, else nil.
    def self.book_at(lines, i)
      s = lines[i].to_s.strip
      prev = prior_stripped(lines, i)
      blob = prev_blob(lines, i)

      case s
      when "GENESIS." then "Genesis"
      when "EXODUS." then "Exodus"
      when "LEVITICUS." then "Leviticus"
      when "NUMBERS." then "Numbers"
      when "DEUTERONOMY." then "Deuteronomy"
      when "THE BOOK OF JOSHUA." then "Joshua"
      when "THE BOOK OF JUDGES." then "Judges"
      when "THE BOOK OF RUTH." then "Ruth"
      when "FIRST BOOK OF SAMUEL," then "1 Samuel"
      when "SECOND BOOK OF SAMUEL," then "2 Samuel"
      when "THE THIRD BOOK OF THE KINGS." then "1 Kings"
      when "THE FOURTH BOOK OF THE KINGS." then "2 Kings"
      when "CHRONICLES."
        return "1 Chronicles" if prev == "THE FIRST BOOK OF THE"
        return "2 Chronicles" if prev == "THE SECOND BOOK OF THE"

        nil
      when "EZRA." then "Ezra"
      when "BOOK OF NEHEMIAH." then "Nehemiah"
      when "BOOK OF ESTHER." then "Esther"
      when "THE BOOK OF JOB." then "Job"
      when "BOOK OF PSALMS." then "Psalms"
      when "THE PROVERBS." then "Proverbs"
      when "ECCLESIASTES;" then "Ecclesiastes"
      when "SONG OF SOLOMON." then "Song of Solomon"
      when "ISAIAH." then "Isaiah"
      when "JEREMIAH." then "Jeremiah"
      when "THE LAMENTATIONS" then "Lamentations"
      when "EZEKIEL." then "Ezekiel"
      when "THE BOOK OF DANIEL." then "Daniel"
      when "HOSEA." then "Hosea"
      when "JOEL." then "Joel"
      when "AMOS." then "Amos"
      when "OBADIAH." then "Obadiah"
      when "JONAH." then "Jonah"
      when "MICAH." then "Micah"
      when "NAHUM." then "Nahum"
      when "HABAKKUK." then "Habakkuk"
      when "ZEPHANIAH." then "Zephaniah"
      when "HAGGAI." then "Haggai"
      when "ZECHARIAH." then "Zechariah"
      when "MALACHI." then "Malachi"
      when "ST. MATTHEW." then "Matthew"
      when "ST. MARK." then "Mark"
      when "ST. LUKE." then "Luke"
      when "ST. JOHN THE DIVINE." then "Revelation"
      when "ST. JOHN." then "John"
      when "ACTS OF THE APOSTLES." then "Acts"
      when "ROMANS." then "Romans"
      when "CORINTHIANS."
        return "1 Corinthians" if blob.include?("FIRST EPISTLE OF PAUL THE APOSTLE")
        return "2 Corinthians" if blob.include?("SECOND EPISTLE OF PAUL THE APOSTLE")

        nil
      when "GALATIANS." then "Galatians"
      when "EPHESIANS." then "Ephesians"
      when "PHILIPPIANS." then "Philippians"
      when "COLOSSIANS." then "Colossians"
      when "THESSALONIANS."
        return "1 Thessalonians" if blob.include?("FIRST EPISTLE OF PAUL THE APOSTLE")
        return "2 Thessalonians" if blob.include?("SECOND EPISTLE OF PAUL THE APOSTLE")

        nil
      when "TIMOTHY."
        return "1 Timothy" if blob.include?("FIRST EPISTLE OF PAUL THE APOSTLE TO")
        return "2 Timothy" if blob.include?("SECOND EPISTLE OF PAUL THE APOSTLE TO")

        nil
      when "TITUS." then "Titus"
      when "PHILEMON." then "Philemon"
      when "HEBREWS." then "Hebrews"
      when "JAMES." then "James"
      when "PETER."
        return "1 Peter" if blob.include?("FIRST EPISTLE GENERAL OF")
        return "2 Peter" if blob.include?("SECOND EPISTLE GENERAL OF")

        nil
      when "JOHN."
        return "1 John" if blob.include?("FIRST EPISTLE GENERAL OF")
        return "2 John" if blob.include?("SECOND EPISTLE OF")
        return "3 John" if blob.include?("THIRD EPISTLE OF")

        nil
      when "JUDE." then "Jude"
      end
    end

    def self.book_label_at_each_index(lines)
      book = "Front matter"
      Array.new(lines.length) do |i|
        nb = book_at(lines, i)
        book = nb if nb
        book
      end
    end

    def self.book_delta_for(event)
      d = event.totals_delta
      case event.kind
      when KjvParseEvent::KIND_PSALM_TITLE
        [1, 0]
      when KjvParseEvent::KIND_SPLIT_VERSE_NUMBER
        [0, 1]
      when KjvParseEvent::KIND_IMPLICIT_PSALM_OPENING
        [0, d[:verse_numbers].to_i]
      when KjvParseEvent::KIND_NUMBERED_LINE, KjvParseEvent::KIND_VERSE_AFTER_PSALM_HEADING
        [d[:chapter_numbers].to_i, d[:verse_numbers].to_i]
      else
        [0, 0]
      end
    end
    private_class_method :book_delta_for

    def self.per_book_counts(lines)
      stats = Hash.new { |h, k| h[k] = { chapters: 0, verses: 0 } }
      labels = book_label_at_each_index(lines)

      KjvLineParser.each_event(lines) do |event|
        i = event.lineno - 1
        b = labels[i]
        ch, vs = book_delta_for(event)
        stats[b][:chapters] += ch
        stats[b][:verses] += vs
      end

      stats
    end

    def self.print_comparison(lines, out: $stdout, all: false)
      actual = per_book_counts(lines)
      mismatch_count = 0

      CANON.each do |name, exp_ch, exp_vs|
        got = actual[name] || { chapters: 0, verses: 0 }
        ch_ok = got[:chapters] == exp_ch
        vs_ok = got[:verses] == exp_vs
        line = "#{name}: chapters #{got[:chapters]} (expected #{exp_ch}), verses #{got[:verses]} (expected #{exp_vs})"
        if all
          out.puts line
        elsif !ch_ok || !vs_ok
          out.puts line
          mismatch_count += 1
        end
      end

      (actual.keys - EXPECTED.keys - ["Front matter"]).each do |name|
        g = actual[name]
        out.puts "#{name}: chapters #{g[:chapters]}, verses #{g[:verses]} (unexpected book bucket)"
        mismatch_count += 1
      end

      if all
        fm = actual["Front matter"]
        out.puts %(Front matter: chapters #{fm[:chapters]}, verses #{fm[:verses]})
      end

      out.puts
      out.puts "Canonical books: #{CANON.size}"
      out.puts(all ? "Printed all #{CANON.size} books (+ front matter)." : "Mismatches vs canon: #{mismatch_count}")
    end
  end
end
