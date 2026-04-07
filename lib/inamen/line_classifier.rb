# frozen_string_literal: true

module Inamen
  # Heuristic line labels for plain-text KJV-style files. Used to inspect structure
  # before changing counting rules. Order of checks matters.
  module LineClassifier
    CATEGORIES = %i[
      chapter verse psalm_heading psalm_119_division colophon book_title unclassified_text other
    ].freeze

    CHAPTER_LINE = /\A[0-9]+\z/
    VERSE_LINE = /\A[0-9]+\s+\S/

    COLOPHON_LINE = /
      \A\[(The\ end|This\ ends).*\]\z
      | \AOr\ the\ (foregoing|preceding).*\z
      | \AWritten\ from\ 
      | \AThe\ .+\ written\ from\ .+\.\z
      | \AWritten\ to\ the\ .+
      | \AUnto\ the\ .+\ written\ from\b
      | \AIt\ was\ written\ to\ .+\bfrom\b
    /ix

    def self.classify(line)
      s = line.to_s.strip
      return :other if s.empty?

      return :chapter if s.match?(CHAPTER_LINE)
      return :psalm_119_division if PsalmHeading.stanza_label?(s)
      return :verse if s.match?(VERSE_LINE)
      return :psalm_heading if PsalmHeading.match?(s)
      return :colophon if s.match?(COLOPHON_LINE)
      return :book_title if book_title?(s)
      # Letter lines that did not match an explicit rule (e.g. unnumbered psalm openers).
      return :unclassified_text if s.match?(/\p{L}/)

      :other
    end

    TITLE_FRAGMENTS = [
      "THE BOOK OF THE PROPHET",
      "THE LAMENTATIONS",
      "THE GENERAL EPISTLE OF",
      "THE THIRD EPISTLE OF",
      "THE REVELATION",
      "OF",
      "ST. JOHN THE DIVINE.",
      "FIRST EPISTLE OF PAUL THE APOSTLE",
      "SECOND EPISTLE OF PAUL THE APOSTLE"
    ].freeze

    def self.book_title?(s)
      return true if TITLE_FRAGMENTS.include?(s)
      return true if %w[
        HOLY\ BIBLE KING\ JAMES\ VERSION THE CALLED THE\ GOSPEL\ ACCORDING\ TO OTHERWISE\ CALLED,
        COMMONLY\ CALLED, THE\ FIRST THE\ SECOND TO\ THE
      ].include?(s)
      return true if s.match?(/\ATHE (FIRST|SECOND|THIRD|FOURTH|FIFTH) BOOK OF MOSES,?\z/)
      return true if s.match?(/\A(FIRST|SECOND) BOOK OF [A-Z ]+,?\z/)
      return true if s.match?(/\ATHE (FIRST|SECOND) BOOK OF THE\z/)
      return true if s.match?(/\ATHE (FIRST|SECOND) BOOK OF THE [A-Z]+\.\z/)
      return true if s.match?(/\ABOOK OF THE KINGS[,.]\z/)
      return true if s.match?(/\ATHE (THIRD|FOURTH) BOOK OF THE KINGS\.\z/)
      return true if s.match?(/\ATHE EPISTLE OF PAUL THE APOSTLE\z/)
      return true if s.match?(/\ATHE EPISTLE OF PAUL TO\z/)
      return true if s.match?(/\AEPISTLE OF PAUL THE APOSTLE TO\z/)
      return true if s.match?(/\ATHE (FIRST|SECOND) EPISTLE GENERAL OF\z/)
      return true if s.match?(/\ATHE SECOND EPISTLE OF\z/)
      return true if s.match?(/\ATHE BOOK OF .+\.\z/)
      return true if s.match?(/\APSALM [0-9]+\z/)
      return true if s.match?(/\AST\. [A-Z.]+\z/)
      return true if s.match?(/\AOR, .+\.\z/)
      return true if s.match?(/\A[A-Z][A-Z\s,'-]+\.\z/) && !s.match?(/[a-z]/)
      return true if s.match?(/\A[A-Z][A-Z\s,]+;\z/)
      return true if s.match?(/\A[A-Z]{3,}\.\z/) && !PsalmHeading.stanza_label?(s)

      false
    end

    # First +limit+ non-empty lines per category (file order).
    def self.sample_lines(lines, limit: 3)
      buckets = CATEGORIES.to_h { |c| [c, []] }
      lines.each do |line|
        cat = classify(line)
        next if buckets[cat].length >= limit

        buckets[cat] << line.to_s.strip
      end
      buckets
    end

    def self.print_sample_report(lines, limit: 3, out: $stdout)
      sample_lines(lines, limit: limit).each do |category, examples|
        out.puts "== #{category} =="
        if examples.empty?
          out.puts "  (no lines matched in this file)"
        else
          examples.each { |ex| out.puts "  #{ex}" }
        end
        out.puts
      end
    end

    # Indices of lines after BOOK OF PSALMS through the line before THE PROVERBS.
    def self.psalms_interior_index_range(lines)
      start_i = lines.index { |l| l.to_s.strip == "BOOK OF PSALMS." }
      end_i = lines.index { |l| l.to_s.strip == "THE PROVERBS." }
      return nil if start_i.nil? || end_i.nil? || end_i <= start_i

      (start_i + 1)...end_i
    end

    # Same lookahead as CountingService for implicit Psalm verse 1 (excludes false positives in debug).
    def self.psalm_implicit_verse_1_body_line?(lines, idx)
      s = lines[idx].to_s.strip
      return false if s.empty?
      return false if PsalmHeading.stanza_label?(s)
      return false if s.match?(/\APSALM [0-9]+\z/)
      return false if PsalmHeading.match?(s)
      return false if s.match?(CHAPTER_LINE)
      return false if s.match?(VERSE_LINE)

      nxt = following_non_empty_line(lines, idx)&.to_s&.strip
      return false unless nxt
      return true if nxt.match?(Inamen::CountingService::PSALM_TITLE)

      vn = Inamen::CountingService.verse_line_number(nxt)
      vn && vn >= 2
    end

    def self.print_psalms_unclassified_report(lines, out: $stdout)
      range = psalms_interior_index_range(lines)
      unless range
        out.puts "Could not find BOOK OF PSALMS. … THE PROVERBS. span."
        return
      end

      count = 0
      range.each do |i|
        raw = lines[i]
        s = raw.to_s.strip
        next if s.empty?
        next if psalm_implicit_verse_1_body_line?(lines, i)
        next unless classify(raw) == :unclassified_text

        count += 1
        out.puts "L#{i + 1}"
        out.puts "  prev: #{prior_non_empty_line(lines, i)&.strip || '(none)'}"
        out.puts "  raw:  #{raw.to_s.chomp}"
        out.puts "  next: #{following_non_empty_line(lines, i)&.strip || '(none)'}"
        out.puts
      end
      out.puts "Total: #{count} unclassified_text line(s) in Psalms body"
    end

    def self.prior_non_empty_line(lines, idx)
      (idx - 1).downto(0) do |j|
        t = lines[j].to_s.strip
        return lines[j] unless t.empty?
      end
      nil
    end

    def self.following_non_empty_line(lines, idx)
      ((idx + 1)...lines.length).each do |j|
        t = lines[j].to_s.strip
        return lines[j] unless t.empty?
      end
      nil
    end
    private_class_method :prior_non_empty_line, :following_non_empty_line
  end
end
