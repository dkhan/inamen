# frozen_string_literal: true

module Inamen
  # Superscription lines after "PSALM n" (not Psalm 119 stanza labels — those are separate).
  module PsalmHeading
    STANZA_LABELS = %w[
      ALEPH. BETH. GIMEL. DALETH. HE. VAU. ZAIN. CHETH. TETH. JOD. CAPH. LAMED. MEM.
      NUN. SAMECH. AIN. PE. TZADDI. KOPH. RESH. SCHIN. TAU.
      א ב ג ד ה ו ז ח ט י כ ל מ נ ס ע פ צ ק ר ש ת
    ].freeze

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
      STANZA_LABELS.include?(stripped_line.to_s.strip)
    end

    def self.match?(stripped_line)
      line = stripped_line.to_s.strip
      line.match?(HEADING_START) || line.match?(RUSSIAN_HEADING_START)
    end
  end
end
