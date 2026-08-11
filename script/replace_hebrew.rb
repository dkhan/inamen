#!/usr/bin/env ruby

INPUT_FILE  = "../data/CONCORD_UPDATED.txt"
OUTPUT_FILE = "../data/CONCORD_NORMALIZED.txt"

HEBREW_LETTERS = {
  "ALEPH"  => "א",
  "BETH"   => "ב",
  "GIMEL"  => "ג",
  "DALETH" => "ד",
  "HE"     => "ה",
  "VAU"    => "ו",
  "ZAIN"   => "ז",
  "CHETH"  => "ח",
  "TETH"   => "ט",
  "JOD"    => "י",
  "CAPH"   => "כ",
  "LAMED"  => "ל",
  "MEM"    => "מ",
  "NUN"    => "נ",
  "SAMECH" => "ס",
  "AIN"    => "ע",
  "PE"     => "פ",
  "TZADDI" => "צ",
  "KOPH"   => "ק",
  "RESH"   => "ר",
  "SCHIN"  => "ש",
  "TAU"    => "ת"
}

text = File.read(INPUT_FILE, encoding: "UTF-8")

text = text.lines.map do |line|
  if line =~ /^(ALEPH|BETH|GIMEL|DALETH|HE|VAU|ZAIN|CHETH|TETH|JOD|CAPH|LAMED|MEM|NUN|SAMECH|AIN|PE|TZADDI|KOPH|RESH|SCHIN|TAU)$/
    "\n#{HEBREW_LETTERS[$1]} #{$1}\n"
  else
    line
  end
end.join

File.write(OUTPUT_FILE, text, encoding: "UTF-8")

puts "Done! Saved to #{OUTPUT_FILE}"