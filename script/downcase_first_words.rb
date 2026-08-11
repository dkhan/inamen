#!/usr/bin/env ruby

if ARGV.length != 2
  abort "Usage: #{$PROGRAM_NAME} INPUT_FILE OUTPUT_FILE"
end

input_file, output_file = ARGV

text = File.read(input_file, encoding: "UTF-8")

text.gsub!(/^([A-Z]+)([^\r\n]*)(\R)(?=2\s)/) do
  first_word = Regexp.last_match(1)
  rest       = Regexp.last_match(2)
  newline    = Regexp.last_match(3)

  if first_word.length == 1
    # Examples:
    # I WILL      -> I will
    # I Was       -> I was
    # I THEREFORE -> I therefore
    # O GOD       -> O God
    # O LORD      -> O LORD
    #
    # Keep the single-letter word unchanged and normalize
    # the following word.

    rest = rest.sub(/^ ([A-Za-z]+)\b/) do
      word = Regexp.last_match(1)

      normalized =
        if word.upcase == "LORD"
          "LORD"
        elsif first_word == "I"
          word.downcase
        else
          word.capitalize
        end

      " #{normalized}"
    end

    "#{first_word}#{rest}#{newline}"

  else
    # Examples:
    # AND -> And
    # NOW -> Now
    # THE LORD -> The LORD
    # LORD -> LORD

    normalized =
      first_word == "LORD" ? first_word : first_word.capitalize

    "#{normalized}#{rest}#{newline}"
  end
end

File.write(output_file, text, encoding: "UTF-8")

puts "Done: #{output_file}"
