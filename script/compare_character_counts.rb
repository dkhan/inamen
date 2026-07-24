#!/usr/bin/env ruby
# frozen_string_literal: true

if ARGV.length != 2
  warn "Usage: ruby compare_character_counts.rb ../data/KJV-PCE.txt ../data/KJV-CONCORD.txt"
  exit 1
end

reference_file = ARGV[0]
concord_file   = ARGV[1]

unless File.file?(reference_file) && File.file?(concord_file)
  warn "Both input files must exist."
  exit 1
end

reference_lines = File.readlines(
  reference_file,
  chomp: true,
  encoding: "UTF-8"
)

concord_lines = File.readlines(
  concord_file,
  chomp: true,
  encoding: "UTF-8"
)

if reference_lines.length != concord_lines.length
  warn "Warning: the files have different line counts."
  warn "#{reference_file}: #{reference_lines.length} lines"
  warn "#{concord_file}: #{concord_lines.length} lines"
  warn "Remove the extra line before comparing corresponding lines."
  exit 1
end

different_lines = 0
total_difference = 0

reference_lines.zip(concord_lines).each_with_index do |(reference, concord), index|
  reference_count = reference.each_char.count
  concord_count   = concord.each_char.count

  next if reference_count == concord_count

  difference = reference_count - concord_count

  different_lines += 1
  total_difference += difference

  puts "=" * 80
  puts "Line #{index + 1}"
  puts
  puts "#{File.basename(reference_file)}: #{reference_count} characters"
  puts reference.inspect
  puts
  puts "#{File.basename(concord_file)}: #{concord_count} characters"
  puts concord.inspect
  puts

  if difference.positive?
    puts "Missing from #{File.basename(concord_file)}: #{difference} character(s)"
  else
    puts "Extra in #{File.basename(concord_file)}: #{difference.abs} character(s)"
  end
end

puts "=" * 80
puts "Lines with different character counts: #{different_lines}"

if total_difference.positive?
  puts "Total characters missing from #{File.basename(concord_file)}: #{total_difference}"
elsif total_difference.negative?
  puts "Total extra characters in #{File.basename(concord_file)}: #{total_difference.abs}"
else
  puts "Net character difference: 0"
end

# ================================================================================
# Line 2324 (Exodus 23:23)

# KJV-PCE.txt, Schyler: 195 characters
# "23 For mine Angel shall go before thee, and bring thee in unto the Amorites, and the Hittites, and the Perizzites, and the Canaanites, and the Hivites, and the Jebusites: and I will cut them off."

# KJV-CONCORD.txt, KJV_OXFORD.txt, Concord, Allan, Thomas Nelson, Holman: 191 characters
# "23 For mine Angel shall go before thee, and bring thee in unto the Amorites, and the Hittites, and the Perizzites, and the Canaanites, the Hivites, and the Jebusites: and I will cut them off."

# Missing from KJV-CONCORD.txt: 4 character(s)
# ================================================================================
# Line 26441 (Mark 2:1)

# KJV-PCE.txt, Schyler: 97 characters
# "AND again he entered into Capernaum, after some days; and it was noised that he was in the house."

# KJV-CONCORD.txt, KJV_OXFORD.txt, Concord, Allan, Thomas Nelson, Holman: 96 characters
# "AND again he entered into Capernaum after some days; and it was noised that he was in the house."

# Missing from KJV-CONCORD.txt: 1 character(s)
# ================================================================================
# Line 31180 (1 Corinthians 15:27)

# KJV-PCE.txt, Schyler: 166 characters
# "27 For he hath put all things under his feet. But when he saith, all things are put under him, it is manifest that he is excepted, which did put all things under him."

# KJV-CONCORD.txt, KJV_OXFORD.txt, Concord, Allan, Thomas Nelson, Holman: 165 characters
# "27 For he hath put all things under his feet. But when he saith all things are put under him, it is manifest that he is excepted, which did put all things under him."

# Missing from KJV-CONCORD.txt: 1 character(s)
# ================================================================================
# Lines with different character counts: 3
# Total characters missing from KJV-CONCORD.txt: 6
