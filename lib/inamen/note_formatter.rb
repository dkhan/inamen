# frozen_string_literal: true

module Inamen
  # Renders a small, safe markdown subset for saved-feature notes.
  module NoteFormatter
    module_function

    def render(text)
      return "" if text.nil? || text.to_s.strip.empty?

      split_blocks(text).map { |block| render_block(block) }.join
    end

    def split_blocks(text)
      blocks = []
      current = []

      text.to_s.gsub("\r\n", "\n").each_line do |line|
        stripped = line.chomp
        if stripped.empty?
          blocks << current unless current.empty?
          current = []
        else
          current << stripped
        end
      end

      blocks << current unless current.empty?
      blocks
    end

    def render_block(lines)
      if lines.all? { |line| list_item?(line) }
        items = lines.map { |line| "<li>#{render_inline(list_item_text(line))}</li>" }
        return "<ul>#{items.join}</ul>"
      end

      content = lines.map { |line| render_inline(line) }.join("<br>\n")
      "<p>#{content}</p>"
    end

    def list_item?(line)
      line.match?(/\A-\s+/)
    end

    def list_item_text(line)
      line.sub(/\A-\s+/, "")
    end

    def render_inline(text)
      escaped = escape_html(text)
      escaped.gsub(/~~(.+?)~~/, '<del>\1</del>')
             .gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
             .gsub(/(?<!\*)\*([^*\n]+?)\*(?!\*)/, '<em>\1</em>')
    end

    def escape_html(text)
      text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub('"', "&quot;")
    end
    private_class_method :escape_html
  end
end
