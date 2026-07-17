#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "net/http"
require "optparse"
require "uri"
require_relative "bible_by_support"

options = {
  version: "syn",
  cache_dir: nil,
  delay: 0.25,
  force: false,
  limit_chapters: nil
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby script/download_bible_by_html.rb -v VERSION [options]"

  parser.on("-v", "--version VERSION", "Bible.by version slug, for example syn") { |value| options[:version] = value }
  parser.on("--cache-dir PATH", "Chapter HTML cache directory") { |value| options[:cache_dir] = value }
  parser.on("--delay SECONDS", Float, "Delay between uncached requests (default: #{options[:delay]})") { |value| options[:delay] = value }
  parser.on("--force", "Re-download cached chapter HTML") { options[:force] = true }
  parser.on("--limit-chapters N", Integer, "Download only the first N chapters, useful for testing") { |value| options[:limit_chapters] = value }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end.parse!

version = BibleBySupport.validate_version!(options[:version])
cache_dir = options[:cache_dir] || BibleBySupport.cache_dir(version)

def fetch_html(url, cache_path, force:, delay:)
  return :cached if File.file?(cache_path) && !force

  uri = URI(url)
  response = nil
  3.times do |attempt|
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 30, open_timeout: 10) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "InamenBibleByDownloader/1.0 (+local research script)"
      request["Accept"] = "text/html,application/xhtml+xml"
      http.request(request)
    end

    break if response.is_a?(Net::HTTPSuccess)

    warn "Retry #{attempt + 1}/3 for #{url}: HTTP #{response.code}"
    sleep(1 + attempt)
  end

  raise "Failed to fetch #{url}: HTTP #{response&.code}" unless response.is_a?(Net::HTTPSuccess)

  html = response.body.force_encoding("UTF-8")
  raise "Invalid UTF-8 from #{url}" unless html.valid_encoding?

  FileUtils.mkdir_p(File.dirname(cache_path))
  File.write(cache_path, html)
  sleep(delay) if delay.positive?
  :downloaded
end

remaining = options[:limit_chapters]
downloaded = 0
cached = 0

BibleBySupport::BOOKS.each do |book|
  break if remaining&.zero?

  puts "Book #{book.id}: #{book.title}"

  (1..book.chapters).each do |chapter|
    break if remaining&.zero?

    url = BibleBySupport.chapter_url(version, book.id, chapter)
    cache_path = File.join(cache_dir, "#{book.id}-#{chapter}.html")
    result = fetch_html(url, cache_path, force: options[:force], delay: options[:delay])
    downloaded += 1 if result == :downloaded
    cached += 1 if result == :cached
    remaining -= 1 if remaining

    puts "  #{url} -> #{result}"
  end
end

puts "Cache: #{cache_dir}"
puts "Downloaded #{downloaded}; already cached #{cached}"
