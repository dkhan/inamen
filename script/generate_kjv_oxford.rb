#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require_relative "../lib/inamen"

module GenerateKjvOxford
  ROOT = Pathname(__dir__).join("..").expand_path
  PCE_PATH = ROOT.join("data/KJB-PCE.txt")
  OXFORD_SOURCE_PATH = ROOT.join("data/KJV_BibleGateway.txt")
  OUTPUT_PATH = ROOT.join("data/KJV_OXFORD.txt")

  VERSE_LINE = Inamen::CountingService::VERSE_LINE
  CHAPTER_WORD_LINE = Inamen::CountingService::CHAPTER_WORD_LINE
  PSALM_TITLE = Inamen::CountingService::PSALM_TITLE

  module_function

  def parse_oxford_verses(lines)
    verses = {}
    book = nil
    chapter = nil

    lines.each do |line|
      stripped = line.to_s.strip
      next if stripped.empty?

      if (canonical = Inamen::BibleBooks.canonical_name(stripped))
        book = canonical
        next
      end

      if stripped.match?(Inamen::CountingService::CHAPTER_LINE)
        chapter = stripped.to_i
        next
      end

      next unless (match = stripped.match(VERSE_LINE))

      key = [book, chapter, match[1].to_i]
      raise "duplicate verse #{key.inspect}" if verses.key?(key)

      verses[key] = match[2]
    end

    verses
  end

  def chapter_number_from(stripped)
    if (match = stripped.match(CHAPTER_WORD_LINE))
      match[1].to_i
    elsif (match = stripped.match(PSALM_TITLE))
      match[0].split.last.to_i
    end
  end

  def pilcrow_after_verse_number?(stripped, verse_number)
    stripped.match?(/\A#{verse_number}\s+¶\s+/)
  end

  def leading_pilcrow?(stripped)
    stripped.start_with?("¶")
  end

  def format_verse_line(raw_line, stripped, verse_number, text, implicit: false)
    if implicit
      prefix = leading_pilcrow?(stripped) ? "¶ " : ""
      return "#{prefix}#{text}"
    end

    prefix =
      if pilcrow_after_verse_number?(stripped, verse_number)
        "#{verse_number} ¶ "
      else
        "#{verse_number} "
      end
    "#{prefix}#{text}"
  end

  def verse_text!(verses, book, chapter, verse, context)
    key = [book, chapter, verse]
    text = verses[key]
    return text if text

    raise "missing Oxford verse #{book} #{chapter}:#{verse} (#{context})"
  end

  def replaceable_verse_event?(event, chapter_verse_started: false)
    case event.kind
    when Inamen::KjvParseEvent::KIND_IMPLICIT_CHAPTER_OPENING,
         Inamen::KjvParseEvent::KIND_IMPLICIT_PSALM_OPENING
      true
    when Inamen::KjvParseEvent::KIND_VERSE_AFTER_PSALM_HEADING
      true
    when Inamen::KjvParseEvent::KIND_NUMBERED_LINE
      return true if event.totals_delta[:verse_numbers].to_i.positive?

      unnumbered_chapter_opening?(event, chapter_verse_started: chapter_verse_started)
    else
      false
    end
  end

  def unnumbered_chapter_opening?(event, chapter_verse_started:)
    return false if chapter_verse_started
    return false unless event.totals_delta[:text_words].to_i.positive?

    classification = event.text_words_debug&.dig(:classification) ||
      Inamen::LineClassifier.classify(event.raw)
    return false if %i[colophon book_title chapter psalm_heading].include?(classification)

    true
  end

  def verse_number_for(event, chapter_verse_started: false)
    case event.kind
    when Inamen::KjvParseEvent::KIND_IMPLICIT_CHAPTER_OPENING,
         Inamen::KjvParseEvent::KIND_IMPLICIT_PSALM_OPENING
      1
    when Inamen::KjvParseEvent::KIND_NUMBERED_LINE
      if event.totals_delta[:verse_numbers].to_i.positive?
        Inamen::KjvLineParser.verse_line_number(event.stripped)
      else
        1
      end
    else
      Inamen::KjvLineParser.verse_line_number(event.stripped)
    end
  end

  def implicit_verse_line?(event, verse_number)
    return true if verse_number == 1 &&
      (event.kind == Inamen::KjvParseEvent::KIND_IMPLICIT_CHAPTER_OPENING ||
       event.kind == Inamen::KjvParseEvent::KIND_IMPLICIT_PSALM_OPENING)

    verse_number == 1 &&
      event.kind == Inamen::KjvParseEvent::KIND_NUMBERED_LINE &&
      event.totals_delta[:verse_numbers].to_i.zero?
  end

  def generate(pce_path: PCE_PATH, oxford_path: OXFORD_SOURCE_PATH, output_path: OUTPUT_PATH)
    pce_lines = File.readlines(pce_path, chomp: true)
    oxford_lines = File.readlines(oxford_path, chomp: true)
    verses = parse_oxford_verses(oxford_lines)

    replacements = {}
    book_labels = Inamen::BookStatsReport.book_label_at_each_index(pce_lines)
    current_book = nil
    current_chapter = nil
    previous_book = nil
    chapter_verse_started = false

    Inamen::KjvLineParser.each_event(pce_lines) do |event|
      idx = event.lineno - 1
      label = book_labels[idx]
      if label != "Front matter" && label != previous_book
        current_book = label
        current_chapter = nil
        previous_book = label
        chapter_verse_started = false
        current_chapter = 1 if Inamen::BookStatsReport::EXPECTED.dig(current_book, :chapters) == 1
      end

      if event.kind == Inamen::KjvParseEvent::KIND_CHAPTER_TITLE ||
         event.kind == Inamen::KjvParseEvent::KIND_PSALM_TITLE
        current_chapter = chapter_number_from(event.stripped)
        chapter_verse_started = false
      end

      next unless replaceable_verse_event?(event, chapter_verse_started: chapter_verse_started)
      next if current_book.nil? || current_book == "Front matter"

      current_chapter = 1 if current_chapter.nil? &&
        Inamen::BookStatsReport::EXPECTED.dig(current_book, :chapters) == 1
      next if current_chapter.nil?

      verse_number = verse_number_for(event, chapter_verse_started: chapter_verse_started)
      text = verse_text!(
        verses,
        current_book,
        current_chapter,
        verse_number,
        "line #{event.lineno}"
      )
      implicit = implicit_verse_line?(event, verse_number)

      replacements[idx] = format_verse_line(
        pce_lines[idx],
        event.stripped,
        verse_number,
        text,
        implicit: implicit
      )
      chapter_verse_started = true
    end

    output_lines = pce_lines.each_with_index.map do |line, idx|
      replacements.fetch(idx, line)
    end

    File.write(output_path, "#{output_lines.join("\n")}\n")
    output_path
  end
end

if $PROGRAM_NAME == __FILE__
  output = GenerateKjvOxford.generate
  puts "Wrote #{output}"
end
