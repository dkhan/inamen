#!/usr/bin/env ruby

INPUT_FILE  = "../data/KJV-CONCORD-PERFECT-TEMP.txt"
OUTPUT_FILE = "../data/KJV-HEBREW.txt"

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

text.gsub!(
  /^(ALEPH|BETH|GIMEL|DALETH|HE|VAU|ZAIN|CHETH|TETH|JOD|CAPH|LAMED|MEM|NUN|SAMECH|AIN|PE|TZADDI|KOPH|RESH|SCHIN|TAU)\.$/
) do
  HEBREW_LETTERS[$1]
end

File.write(OUTPUT_FILE, text, encoding: "UTF-8")

puts "Done! Saved to #{OUTPUT_FILE}"