#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "optparse"
require_relative "../lib/inamen"
require_relative "bible_by_support"

begin
  require "nokogiri"
rescue LoadError
  warn "This script requires nokogiri. Run it from web/ with Bundler, for example:"
  warn "  cd web && bundle exec ruby ../script/combine_bible_by_txt.rb -v syn"
  exit 1
end

options = {
  version: "syn",
  cache_dir: nil,
  output: nil,
  limit_chapters: nil
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby script/combine_bible_by_txt.rb -v VERSION [options]"

  parser.on("-v", "--version VERSION", "Bible.by version slug, for example syn") { |value| options[:version] = value }
  parser.on("-o", "--output PATH", "Combined output .txt path") { |value| options[:output] = value }
  parser.on("--cache-dir PATH", "Chapter HTML cache directory") { |value| options[:cache_dir] = value }
  parser.on("--limit-chapters N", Integer, "Combine only the first N chapters, useful for testing") { |value| options[:limit_chapters] = value }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end.parse!

version = BibleBySupport.validate_version!(options[:version])
cache_dir = options[:cache_dir] || BibleBySupport.cache_dir(version)
output = options[:output] || BibleBySupport.default_output(version)

def clean_text(value)
  value.to_s
       .gsub("\u00A0", " ")
       .gsub(/[ \t]+/, " ")
       .gsub(/\s+([,.;:!?])/, "\\1")
       .strip
end

def verse_line?(line)
  line.match?(/\A\d+\s+\S/)
end

def superscription_line(line)
  "#{Inamen::LineClassifier::IMPORTED_SUPERSCRIPTION_PREFIX}#{line.sub(/\A(\d+)\s+/, "\\1. ")}"
end

def extract_chapter_lines(html, version, book, chapter)
  doc = Nokogiri::HTML(html)
  doc.css("script, style, noscript, svg").remove

  root = doc.at_css(%(div.text[data-link-base="#{version}"][data-book="#{book.id}"][data-chapter="#{chapter}"]))
  root ||= doc.at_css(%(div.text[data-book="#{book.id}"][data-chapter="#{chapter}"]))
  root ||= doc.at_css(%(div.text[data-link-base="#{version}"]))
  root ||= doc.at_css("div.text")
  raise "Could not find chapter text container for #{book.title} #{chapter}" unless root

  summaries = root.css(".top-paragraph").filter_map do |node|
    line = clean_text(node.text)
    line.empty? ? nil : superscription_line(line)
  end

  verses = root.xpath("./div[@id and string(number(@id)) != 'NaN']").filter_map do |node|
    number = node["id"].to_i
    text = clean_text(node.text.sub(/\A\s*#{number}\s*/, ""))
    text.empty? ? nil : "#{number} #{text}"
  end

  raise "Could not extract verses for #{book.title} #{chapter}" if verses.empty?

  summaries + verses
end

FileUtils.mkdir_p(File.dirname(output))

remaining = options[:limit_chapters]
all_lines = ["Библия. Bible.by #{version}", ""]

BibleBySupport::BOOKS.each do |book|
  break if remaining&.zero?

  puts "Book #{book.id}: #{book.title}"
  all_lines << book.title

  (1..book.chapters).each do |chapter|
    break if remaining&.zero?

    cache_path = File.join(cache_dir, "#{book.id}-#{chapter}.html")
    raise "Missing cached chapter HTML: #{cache_path}" unless File.file?(cache_path)

    html = File.read(cache_path, encoding: "UTF-8")
    chapter_lines = extract_chapter_lines(html, version, book, chapter)

    all_lines << ""
    all_lines << "Глава #{chapter}"
    all_lines.concat(chapter_lines)
    remaining -= 1 if remaining

    puts "  #{BibleBySupport.chapter_url(version, book.id, chapter)} -> #{chapter_lines.count { |line| verse_line?(line) }} verse line(s)"
  end

  all_lines << ""
end

File.write(output, "#{all_lines.join("\n").rstrip}\n")
puts "Wrote #{output}"
