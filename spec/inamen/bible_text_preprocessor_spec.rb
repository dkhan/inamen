# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Inamen::BibleTextPreprocessor do
  def with_text_file(text)
    file = Tempfile.new(["edition", ".txt"])
    file.write(text)
    file.close
    yield file.path
  ensure
    file&.unlink
  end

  it "trims outside matter and keeps Bible structure including Apocrypha" do
    text = <<~TEXT
      Publisher introduction

      Genesis
      Chapter 1
      In the beginning God created the heaven and the earth.
      2 And the earth was without form.
      A Psalm of David.
      [The end of Genesis.]

      Tobit
      1
      1 The book of the words of Tobit.

      Back matter
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)

      expect(result.books).to eq(["Genesis", "Tobit"])
      expect(result.lines).to include("Genesis", "CHAPTER 1", "Tobit", "1")
      expect(result.lines).to include("In the beginning God created the heaven and the earth.")
      expect(result.lines).not_to include("Publisher introduction")
      expect(result.lines).not_to include("Back matter")
    end
  end

  it "keeps Psalm chapter titles, superscriptions, and implicit verse openings" do
    text = <<~TEXT
      Psalms
      PSALM 1
      Blessed is the man that walketh not in the counsel of the ungodly.
      2 But his delight is in the law of the LORD.

      PSALM 2
      A Psalm of David.
      Why do the heathen rage?
      2 The kings of the earth set themselves.
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)

      expect(result.books).to eq(["Psalms"])
      expect(result.lines).to include("PSALM 1", "PSALM 2")
      expect(result.lines).to include("A Psalm of David.")
      expect(result.lines).to include("Blessed is the man that walketh not in the counsel of the ungodly.")
      expect(result.lines).to include("Why do the heathen rage?")
    end
  end

  it "normalizes Russian Synodal 77 structure with wrapped verses and special sections" do
    text = <<~TEXT
      БИБЛИЯ
      ВЕТХИЙ ЗАВЕТ
      Бытие
      1
      1 В начале сотворил Бог небо
      и землю.
      2 Земля же была безвидна.
      Вторая книга Паралипоменон
      36
      23 Кто есть из вас.
      [МОЛИТВА МАНАССИИ, ЦАРЯ ИУДЕЙСКОГО
      Господи Вседержителю, Боже отцев наших.
      Первая книга Ездры
      1
      1 В первый год Кира.
      Книга Есфири
      Предисловие
      [Во второй год царствования Артаксеркса сон видел Мардохей.]
      1
      1 И было во дни Артаксеркса.
      Книга Премудрости Иисуса, сына Сирахова *
      Предисловие
      1 Многое и великое дано нам через закон,
      2 следовавших за ними.
      1
      1 Всякая премудрость - от Господа.
      Первое послание к Фессалоникийцам (Солунянам) святого апостола
      Павла
      1
      1 Павел и Силуан.
      Третья книга Маккавейская *
      1
      1 Филопатор узнал.
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)
      index = Inamen::VerseIndex.build_chapter_index(result.lines)

      expect(result.language).to eq("ru")
      expect(result.canon).to eq("russian_synodal_77")
      expect(result.books).to eq([
        "Genesis", "2 Chronicles", "Ezra", "Esther", "Sirach", "1 Thessalonians", "3 Maccabees"
      ])
      expect(index.dig("Genesis", 1, 1)).to eq("В начале сотворил Бог небо и землю.")
      expect(index.dig("Esther", 1, 1)).to eq("И было во дни Артаксеркса.")
      expect(index.dig("Sirach", 1, 1)).to eq("Всякая премудрость - от Господа.")
      expect(index.dig("1 Thessalonians", 1, 1)).to eq("Павел и Силуан.")
      expect(index.dig("3 Maccabees", 1, 1)).to eq("Филопатор узнал.")
      expect(result.lines.grep(/\A#{Regexp.escape(Inamen::LineClassifier::IMPORTED_SPECIAL_PREFIX)}/).length).to eq(7)
    end
  end

  it "rejects binary files" do
    with_text_file("Genesis\x00Chapter 1") do |path|
      expect { described_class.from_file(path) }.to raise_error(described_class::Error, /binary/)
    end
  end

  it "rejects invalid UTF-8" do
    file = Tempfile.new(["edition", ".txt"])
    file.binmode
    file.write("\xC3\x28")
    file.close

    expect { described_class.from_file(file.path) }.to raise_error(described_class::Error, /encoding/)
  ensure
    file&.unlink
  end
end
