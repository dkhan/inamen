# frozen_string_literal: true

module Inamen
  # Superscription lines after "PSALM n" (not Psalm 119 stanza labels — those are separate).
  module PsalmHeading
    STANZA_LABELS = %w[
      ALEPH. BETH. GIMEL. DALETH. HE. VAU. ZAIN. CHETH. TETH. JOD. CAPH. LAMED. MEM.
      NUN. SAMECH. AIN. PE. TZADDI. KOPH. RESH. SCHIN. TAU.
      ALEPH BETH GIMEL DALETH HE VAU ZAIN CHETH TETH JOD CAPH LAMED MEM
      NUN SAMECH AIN PE TZADDI KOPH RESH SCHIN TAU
      א ב ג ד ה ו ז ח ט י כ ל מ נ ס ע פ צ ק ר ש ת
    ].freeze
    LATIN_STANZA_LABELS = %w[
      ALEPH BETH GIMEL DALETH HE VAU ZAIN CHETH TETH JOD CAPH LAMED MEM
      NUN SAMECH AIN PE TZADDI KOPH RESH SCHIN TAU
    ].freeze
    HEBREW_STANZA_LABEL = /\A\p{Hebrew}\s+[A-Z]+\.?\z/

    # To the chief Musician; A Psalm and Song; A Psalm of; Maschil; Michtam; Shiggaion;
    # A Prayer of; A Song of degrees; A Song of … (degrees must precede generic Song of).
    # KJV also uses A Song and Psalm …; A Psalm for …; A Psalm or Song …; A Psalm.; David’s Psalm …
    HEADING_START = /
      \ATo\ the\ chief\ Musician
      | \AA\ Psalm\ and\ Song
      | \AA\ Song\ and\ Psalm\b
      | \AA\ Psalm\ for\ 
      | \AA\ Song\ or\ Psalm\b
      | \AA\ Psalm\ or\ Song\b
      | \AA\ Psalm\ of\ 
      | \AMaschil\b
      | \AMichtam\b
      | \AShiggaion\b
      | \AA\ Prayer\ of\ 
      | \AA\ Song\ of\ degrees
      | \AA\ Song\ of\ 
      | \AA\ Psalm\.\z
      | \ADavid(?:\u{2019}|')s\ Psalm\ of\ praise
    /ix

    RUSSIAN_HEADING_START = /
      \AПсалом\b
      | \AНачальнику\ хора\b
      | \AПеснь\b
      | \AУчение\b
      | \AСынов\ Кореевых\b
      | \AМолитва\b
      | \AХвалебная\ песнь\b
    /ix

    def self.stanza_label?(stripped_line)
      stanza_word_count(stripped_line).positive? || stanza_division_count(stripped_line).positive?
    end

    def self.stanza_word_count(stripped_line)
      line = stripped_line.to_s.strip
      return 1 if latin_stanza_label?(line)
      return 1 if line.match?(HEBREW_STANZA_LABEL) && latin_stanza_label?(line.split(/\s+/, 2).last.to_s)

      0
    end

    def self.stanza_division_count(stripped_line)
      line = stripped_line.to_s.strip
      return 0 if stanza_word_count(line).positive?
      return 1 if STANZA_LABELS.include?(line)

      0
    end

    def self.latin_stanza_label?(line)
      LATIN_STANZA_LABELS.include?(line.to_s.delete_suffix("."))
    end
    private_class_method :latin_stanza_label?

    def self.match?(stripped_line)
      line = stripped_line.to_s.strip
      line.match?(HEADING_START) || line.match?(RUSSIAN_HEADING_START)
    end
  end
end
