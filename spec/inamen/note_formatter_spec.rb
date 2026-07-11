# frozen_string_literal: true

require "inamen/note_formatter"

RSpec.describe Inamen::NoteFormatter do
  describe ".render" do
    it "returns an empty string for blank input" do
      expect(described_class.render(nil)).to eq("")
      expect(described_class.render("")).to eq("")
    end

    it "preserves single line breaks inside a paragraph" do
      html = described_class.render("Line one\nLine two")
      expect(html).to eq("<p>Line one<br>\nLine two</p>")
    end

    it "starts a new paragraph after a blank line" do
      html = described_class.render("First block\n\nSecond block")
      expect(html).to eq("<p>First block</p><p>Second block</p>")
    end

    it "renders bold, italic, and strikethrough" do
      html = described_class.render("**bold** *italic* ~~strike~~")
      expect(html).to eq("<p><strong>bold</strong> <em>italic</em> <del>strike</del></p>")
    end

    it "renders bullet lists" do
      html = described_class.render("- first\n- second")
      expect(html).to eq("<ul><li>first</li><li>second</li></ul>")
    end

    it "formats bullets and inline styles together" do
      html = described_class.render("- **bold** item\n- ~~old~~ item")
      expect(html).to eq("<ul><li><strong>bold</strong> item</li><li><del>old</del> item</li></ul>")
    end

    it "escapes HTML" do
      html = described_class.render("<script>alert(1)</script>")
      expect(html).to eq("<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>")
      expect(html).not_to include("<script>")
    end
  end
end
