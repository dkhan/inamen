# frozen_string_literal: true

require "inamen/verse_highlighter"

RSpec.describe Inamen::VerseHighlighter do
  describe ".highlight_text" do
    it "preserves punctuation around highlighted Russian words" do
      text = "благодать же Господа нашего (Иисуса Христа) открылась"

      html = described_class.highlight_text(text, [5, 6]).to_s

      expect(html).to eq(
        'благодать же Господа нашего (<mark class="search-hit">Иисуса</mark> ' \
        '<mark class="search-hit">Христа</mark>) открылась'
      )
    end

    it "escapes original text while preserving separators" do
      html = described_class.highlight_text("A <B> & C", [2]).to_s

      expect(html).to eq('A &lt;<mark class="search-hit">B</mark>&gt; &amp; C')
    end
  end
end
