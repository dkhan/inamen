# frozen_string_literal: true

RSpec.describe Inamen::CountingService do
  describe ".counts_for_line" do
    it "treats a lone number as a chapter marker" do
      expect(described_class.counts_for_line("42")).to eq(
        text_words: 0, verse_text_words: 0, psalm_heading_words: 0, psalm_119_division_words: 0,
        chapter_numbers: 1, verse_numbers: 0
      )
    end

    it "counts leading verse number and body words separately" do
      expect(described_class.counts_for_line("3 And God said, Let there be light.")).to eq(
        text_words: 0, verse_text_words: 7, psalm_heading_words: 0, psalm_119_division_words: 0,
        chapter_numbers: 0, verse_numbers: 1
      )
    end

    it "counts prose lines as text words only" do
      expect(described_class.counts_for_line("And God said, Let there be light.")).to eq(
        text_words: 7, verse_text_words: 0, psalm_heading_words: 0, psalm_119_division_words: 0,
        chapter_numbers: 0, verse_numbers: 0
      )
    end

    it "counts an all-caps book title token as one text word" do
      expect(described_class.counts_for_line("GENESIS")).to eq(
        text_words: 1, verse_text_words: 0, psalm_heading_words: 0, psalm_119_division_words: 0,
        chapter_numbers: 0, verse_numbers: 0
      )
    end

    it "counts five-word title lines correctly" do
      expect(described_class.counts_for_line("THE FIRST BOOK OF MOSES")).to eq(
        text_words: 5, verse_text_words: 0, psalm_heading_words: 0, psalm_119_division_words: 0,
        chapter_numbers: 0, verse_numbers: 0
      )
    end

    it "counts a two-digit verse prefix like a one-digit verse" do
      expect(described_class.counts_for_line("12 And God said, Let there be light.")).to eq(
        text_words: 0, verse_text_words: 7, psalm_heading_words: 0, psalm_119_division_words: 0,
        chapter_numbers: 0, verse_numbers: 1
      )
    end
  end

  describe ".combined_total" do
    it "sums all counted buckets (excluding debug-only fields)" do
      counts = described_class.empty_counts.merge(
        text_words: 1,
        verse_text_words: 7,
        psalm_heading_words: 5,
        psalm_119_division_words: 2,
        chapter_numbers: 1,
        verse_numbers: 2
      )
      expect(described_class.combined_total(counts)).to eq(18)
    end
  end

  describe ".labeled_tokens_for_line" do
    it "tags chapter, verse, and verse body tokens" do
      expect(described_class.labeled_tokens_for_line("2")).to eq([[:chapter_number, "2"]])
      expect(described_class.labeled_tokens_for_line("1 IN the beginning")).to eq(
        [
          [:verse_number, "1"],
          [:verse_text_word, "IN"],
          [:verse_text_word, "the"],
          [:verse_text_word, "beginning"]
        ]
      )
    end
  end

  describe ".total_for_lines" do
    it "counts PSALM 10: implicit verse 1 then numbered verse 2 (KJV structure)" do
      v1 = "WHY standest thou afar off, O LORD? why hidest thou thyself in times of trouble?"
      v2 = "2 The wicked in his pride doth persecute the poor: let them be taken in the devices that they have imagined."
      lines = ["PSALM 10", v1, v2]

      v1_n = Inamen::Tokenizer.tokenize(v1).size
      v2_body = v2.sub(/\A[0-9]+\s+/, "")
      v2_n = Inamen::Tokenizer.tokenize(v2_body).size

      c = described_class.total_for_lines(lines)
      expect(c[:chapter_numbers]).to eq(1)
      expect(c[:verse_numbers]).to eq(2)
      expect(c[:psalm_heading_words]).to eq(0)
      expect(c[:psalm_119_division_words]).to eq(0)
      expect(c[:verse_text_words]).to eq(v1_n + v2_n)
      expect(c[:psalm_chapter_titles]).to eq(1)
      expect(c[:numeric_chapter_lines]).to eq(0)
      expect(c[:implicit_psalm_verse_1]).to eq(1)
      expect(c[:numbered_verse_lines]).to eq(1)
    end

    it "counts PSALM 11: heading then implicit verse 1 then verse 2" do
      heading = "To the chief Musician, A Psalm of David."
      v1 = "IN the LORD put I my trust: how say ye to my soul, Flee as a bird to your mountain?"
      v2 = "2 For, lo, the wicked bend their bow, they make ready their arrow upon the string, that they may privily shoot at the upright in heart."
      lines = ["PSALM 11", heading, v1, v2]

      h_n = Inamen::Tokenizer.tokenize(heading).size
      v1_n = Inamen::Tokenizer.tokenize(v1).size
      v2_body = v2.sub(/\A[0-9]+\s+/, "")
      v2_n = Inamen::Tokenizer.tokenize(v2_body).size

      c = described_class.total_for_lines(lines)
      expect(c[:chapter_numbers]).to eq(1)
      expect(c[:verse_numbers]).to eq(2)
      expect(c[:psalm_heading_words]).to eq(h_n)
      expect(c[:verse_text_words]).to eq(v1_n + v2_n)
      expect(c[:implicit_psalm_verse_1]).to eq(1)
      expect(c[:numbered_verse_lines]).to eq(1)
    end

    it "counts PSALM 30: A Psalm and Song heading then implicit verse 1" do
      heading = "A Psalm and Song at the dedication of the house of David."
      v1 = "I WILL extol thee, O LORD; for thou hast lifted me up, and hast not made my foes to rejoice over me."
      v2 = "2 O LORD my God, I cried unto thee, and thou hast healed me."
      lines = ["PSALM 30", heading, v1, v2]

      h_n = Inamen::Tokenizer.tokenize(heading).size
      v1_n = Inamen::Tokenizer.tokenize(v1).size
      v2_body = v2.sub(/\A[0-9]+\s+/, "")
      v2_n = Inamen::Tokenizer.tokenize(v2_body).size

      c = described_class.total_for_lines(lines)
      expect(c[:chapter_numbers]).to eq(1)
      expect(c[:verse_numbers]).to eq(2)
      expect(c[:psalm_heading_words]).to eq(h_n)
      expect(c[:verse_text_words]).to eq(v1_n + v2_n)
    end

    it "counts PSALM 33: implicit verse 1 then numbered verse 2" do
      v1 = "REJOICE in the LORD, O ye righteous: for praise is comely for the upright."
      v2 = "2 Praise the LORD with harp: sing unto him with the psaltery and an instrument of ten strings."
      lines = ["PSALM 33", v1, v2]

      v1_n = Inamen::Tokenizer.tokenize(v1).size
      v2_body = v2.sub(/\A[0-9]+\s+/, "")
      v2_n = Inamen::Tokenizer.tokenize(v2_body).size

      c = described_class.total_for_lines(lines)
      expect(c[:chapter_numbers]).to eq(1)
      expect(c[:verse_numbers]).to eq(2)
      expect(c[:psalm_heading_words]).to eq(0)
      expect(c[:verse_text_words]).to eq(v1_n + v2_n)
    end

    it "treats split verse-1 line after a numeric chapter line (Isaiah 58 in KJV.txt)" do
      body = "CRY aloud, spare not, lift up thy voice like a trumpet."
      lines = ["58", "1", body]
      c = described_class.total_for_lines(lines)
      expect(c[:chapter_numbers]).to eq(1)
      expect(c[:verse_numbers]).to eq(1)
      expect(c[:numeric_chapter_lines]).to eq(1)
      expect(c[:numbered_verse_lines]).to eq(1)
      expect(c[:verse_text_words]).to eq(Inamen::Tokenizer.tokenize(body).size)
    end

    it "counts PSALM 1: implicit verse 1 text then numbered verse 2" do
      v1 = "BLESSED is the man that walketh not in the counsel of the ungodly, " \
           "nor standeth in the way of sinners, nor sitteth in the seat of the scornful."
      v2 = "2 But his delight is in the law of the LORD; and in his law doth he meditate day and night."
      lines = ["PSALM 1", v1, v2]

      v1_n = Inamen::Tokenizer.tokenize(v1).size
      v2_body = v2.sub(/\A[0-9]+\s+/, "")
      v2_n = Inamen::Tokenizer.tokenize(v2_body).size

      c = described_class.total_for_lines(lines)
      expect(c[:chapter_numbers]).to eq(1)
      expect(c[:verse_numbers]).to eq(2)
      expect(c[:verse_text_words]).to eq(v1_n + v2_n)
      expect(c[:implicit_psalm_verse_1]).to eq(1)
    end

    it "counts PSALM 48: KJV heading then implicit verse 1 then verse 2" do
      heading = "A Song and Psalm for the sons of Korah."
      v1 = "GREAT is the LORD, and greatly to be praised in the city of our God, in the mountain of his holiness."
      v2 = "2 Beautiful for situation, the joy of the whole earth, is mount Zion, on the sides of the north, the city of the great King."
      lines = ["PSALM 48", heading, v1, v2]

      h_n = Inamen::Tokenizer.tokenize(heading).size
      v1_n = Inamen::Tokenizer.tokenize(v1).size
      v2_body = v2.sub(/\A[0-9]+\s+/, "")
      v2_n = Inamen::Tokenizer.tokenize(v2_body).size

      c = described_class.total_for_lines(lines)
      expect(c[:chapter_numbers]).to eq(1)
      expect(c[:verse_numbers]).to eq(2)
      expect(c[:psalm_heading_words]).to eq(h_n)
      expect(c[:verse_text_words]).to eq(v1_n + v2_n)
      expect(c[:implicit_psalm_verse_1]).to eq(1)
    end

    it "counts PSALM 145: David’s Psalm of praise then implicit verse 1 then verse 2" do
      heading = "David\u{2019}s Psalm of praise."
      v1 = "I WILL extol thee, my God, O king; and I will bless thy name for ever and ever."
      v2 = "2 Every day will I bless thee; and I will praise thy name for ever and ever."
      lines = ["PSALM 145", heading, v1, v2]

      h_n = Inamen::Tokenizer.tokenize(heading).size
      v1_n = Inamen::Tokenizer.tokenize(v1).size
      v2_body = v2.sub(/\A[0-9]+\s+/, "")
      v2_n = Inamen::Tokenizer.tokenize(v2_body).size

      c = described_class.total_for_lines(lines)
      expect(c[:chapter_numbers]).to eq(1)
      expect(c[:verse_numbers]).to eq(2)
      expect(c[:psalm_heading_words]).to eq(h_n)
      expect(c[:verse_text_words]).to eq(v1_n + v2_n)
      expect(c[:implicit_psalm_verse_1]).to eq(1)
    end

    it "counts superscription tokens into psalm_heading_words before implicit verse 1" do
      lines = [
        "PSALM 3",
        "A Psalm of David, when he fled from Absalom his son.",
        "LORD, how are they increased that trouble me! many are they that rise up against me.",
        "2 Many there be which say of my soul, There is no help for him in God. Selah."
      ]
      h_n = Inamen::Tokenizer.tokenize(lines[1]).size
      v1_n = Inamen::Tokenizer.tokenize(lines[2]).size
      v2_body = lines[3].sub(/\A[0-9]+\s+/, "")
      v2_n = Inamen::Tokenizer.tokenize(v2_body).size

      c = described_class.total_for_lines(lines)
      expect(c[:chapter_numbers]).to eq(1)
      expect(c[:verse_numbers]).to eq(2)
      expect(c[:psalm_heading_words]).to eq(h_n)
      expect(c[:verse_text_words]).to eq(v1_n + v2_n)
    end

    it "counts Psalm 119 stanza labels in psalm_119_division_words, not psalm_heading_words" do
      v1 = "BLESSED are the undefiled in the way, who walk in the law of the LORD."
      v2 = "2 Blessed are they that keep his testimonies, and that seek him with the whole heart."
      lines = ["PSALM 119", "ALEPH.", v1, v2]

      stanza_n = Inamen::Tokenizer.tokenize("ALEPH.").size
      v1_n = Inamen::Tokenizer.tokenize(v1).size
      v2_body = v2.sub(/\A[0-9]+\s+/, "")
      v2_n = Inamen::Tokenizer.tokenize(v2_body).size

      c = described_class.total_for_lines(lines)
      expect(c[:psalm_119_division_words]).to eq(stanza_n)
      expect(c[:psalm_heading_words]).to eq(0)
      expect(c[:verse_text_words]).to eq(v1_n + v2_n)
      expect(c[:implicit_psalm_verse_1]).to eq(1)
      expect(c[:numbered_verse_lines]).to eq(1)
    end

    it "increments numeric_chapter_lines for digit-only chapter lines" do
      c = described_class.total_for_lines(["1", "1 IN the beginning"])
      expect(c[:numeric_chapter_lines]).to eq(1)
      expect(c[:psalm_chapter_titles]).to eq(0)
      expect(c[:numbered_verse_lines]).to eq(1)
    end
  end
end
