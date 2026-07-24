#!/usr/bin/env ruby
# frozen_string_literal: true

require "diff/lcs"
require "diff/lcs/hunk"

if ARGV.length != 2
  warn "Usage: ruby unique_diffs.rb  ../data/KJV-PCE.txt ../data/KJV-CONCORD.txt"
  exit 1
end

old_file, new_file = ARGV

unless File.file?(old_file) && File.file?(new_file)
  warn "Both input files must exist."
  exit 1
end

old_lines = File.readlines(old_file, chomp: true, encoding: "UTF-8")
new_lines = File.readlines(new_file, chomp: true, encoding: "UTF-8")

counts = Hash.new(0)

Diff::LCS.sdiff(old_lines, new_lines).each do |change|
  next unless change.action == "!"

  old_line = change.old_element
  new_line = change.new_element

  old_words = old_line.scan(/[[:alpha:]’'-]+|[^\s[:alpha:]’'-]+/)
  new_words = new_line.scan(/[[:alpha:]’'-]+|[^\s[:alpha:]’'-]+/)

  Diff::LCS.sdiff(old_words, new_words).each do |word_change|
    next unless word_change.action == "!"

    from = word_change.old_element
    to   = word_change.new_element

    next if from == to

    counts[[from, to]] += 1
  end
end

counts
  .sort_by { |(from, to), count| [-count, from, to] }
  .each do |(from, to), count|
    puts "#{from} -> #{to}: #{count}"
  end

# Lord -> LORD: 6452
# God -> GOD: 308
# Lord’s -> LORD’S: 108
# inquire -> enquire: 48
# inquired -> enquired: 34
# counsellers -> counsellors: 21
# counseller -> counsellor: 13
# rasor -> razor: 7
# Inquire -> Enquire: 4
# spirit -> Spirit: 3
# expences -> expenses: 2
# inquiry -> enquiry: 2
# ? -> .: 1
# AUTHORIZED -> KING: 1
# Counseller -> Counsellor: 1
# Geba -> Gaba: 1
# ancle -> ankle: 1
# ancles -> ankles: 1
# inquirest -> enquirest: 1
# —; -> –;: 1