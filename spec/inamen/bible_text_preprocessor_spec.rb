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

  it "keeps Hebrew Psalm 119 stanza labels separate from implicit verse openings" do
    text = <<~TEXT
      Psalms
      PSALM 119
      א
      BLESSED are the undefiled in the way, who walk in the law of the LORD.
      2 Blessed are they that keep his testimonies, and that seek him with the whole heart.
      ב
      9 Wherewithal shall a young man cleanse his way? by taking heed thereto according to thy word.
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)
      index = Inamen::VerseIndex.build_chapter_index(result.lines)

      expect(result.lines).to include("א", "ב")
      expect(index.dig("Psalms", 119, 1)).to eq(
        "BLESSED are the undefiled in the way, who walk in the law of the LORD."
      )
      expect(index.dig("Psalms", 119, 2)).to eq(
        "Blessed are they that keep his testimonies, and that seek him with the whole heart."
      )
      expect(index.dig("Psalms", 119, 9)).to eq(
        "Wherewithal shall a young man cleanse his way? by taking heed thereto according to thy word."
      )
    end
  end

  it "keeps non-Psalm chapter openings that look like Psalm headings as verse text" do
    text = <<~TEXT
      Habakkuk
      CHAPTER 3
      A PRAYER of Habakkuk the prophet upon Shigionoth.
      2 O LORD, I have heard thy speech, and was afraid.
      3 God came from Teman, and the Holy One from mount Paran. Selah.
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)
      index = Inamen::VerseIndex.build_chapter_index(result.lines)

      expect(index.dig("Habakkuk", 3, 1)).to eq("A PRAYER of Habakkuk the prophet upon Shigionoth.")
      expect(index.dig("Habakkuk", 3, 2)).to eq("O LORD, I have heard thy speech, and was afraid.")
      expect(result.lines).not_to include(
        "#{Inamen::LineClassifier::IMPORTED_SUPERSCRIPTION_PREFIX}A PRAYER of Habakkuk the prophet upon Shigionoth."
      )
    end
  end

  it "recognizes KJV-style book headings without final periods" do
    text = <<~TEXT
      THE THIRD BOOK OF THE KINGS
      CHAPTER 1
      1 Now king David was old.

      THE FIRST BOOK OF THE
      CHRONICLES
      CHAPTER 1
      1 Adam, Sheth, Enosh,

      THE PROVERBS
      CHAPTER 1
      1 The proverbs of Solomon.

      ACTS OF THE APOSTLES
      CHAPTER 1
      1 The former treatise have I made.

      THE FIRST EPISTLE OF PAUL THE APOSTLE
      TO THE
      CORINTHIANS
      CHAPTER 1
      1 Paul called to be an apostle.

      THE FIRST EPISTLE GENERAL OF
      PETER
      CHAPTER 1
      1 Peter, an apostle of Jesus Christ.

      THE SECOND EPISTLE OF
      JOHN
      1 The elder unto the elect lady.

      OBADIAH
      THE vision of Obadiah. Thus saith the Lord GOD concerning Edom;
      2 Behold, I have made thee small among the heathen.
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)
      index = Inamen::VerseIndex.build_chapter_index(result.lines)

      expect(result.books).to eq([
        "1 Kings", "1 Chronicles", "Proverbs", "Acts", "1 Corinthians", "1 Peter", "2 John", "Obadiah"
      ])
      expect(index.dig("Obadiah", 1, 1)).to eq(
        "THE vision of Obadiah. Thus saith the Lord GOD concerning Edom;"
      )
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
      50
      31 а если будет исполнять, то все возможет; ибо свет Господень - путь его. Молитва Иисуса,
      сына Сирахова
      51
      1 Прославлю Тебя, Господи Царю.
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
      expect(index.dig("Sirach", 50, 31)).to eq("а если будет исполнять, то все возможет; ибо свет Господень - путь его.")
      expect(index.dig("Sirach", 51, 1)).to eq("Прославлю Тебя, Господи Царю.")
      expect(index.dig("1 Thessalonians", 1, 1)).to eq("Павел и Силуан.")
      expect(index.dig("3 Maccabees", 1, 1)).to eq("Филопатор узнал.")
      special_lines = result.lines.grep(/\A#{Regexp.escape(Inamen::LineClassifier::IMPORTED_SPECIAL_PREFIX)}/)
      expect(special_lines.length).to eq(8)
      expect(special_lines).to include("#{Inamen::LineClassifier::IMPORTED_SPECIAL_PREFIX}Молитва Иисуса, сына Сирахова")
    end
  end

  it "normalizes Russian Psalm superscriptions without blank-line separators" do
    text = <<~TEXT
      БИБЛИЯ
      Бытие
      1
      1 В начале сотворил Бог небо и землю.
      Псалтирь
      1
      Псалом Давида.
      1 Блажен муж.
      2 Но в законе Господа воля его.
      17
      1 Начальнику хора. Раба Господня Давида, который произнес слова песни сей к Господу,
      когда Господь избавил его от рук всех врагов его и от руки Саула. И он сказал:
      2 Возлюблю Тебя, Господи, крепость моя!
      3 Господь - твердыня моя.
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)
      index = Inamen::VerseIndex.build_chapter_index(result.lines)

      expect(result.books).to eq(["Genesis", "Psalms"])
      expect(result.lines).to include("PSALM 1", "PSALM 17")
      expect(result.lines).to include("Псалом Давида.")
      expect(result.lines).to include(
        "Начальнику хора. Раба Господня Давида, который произнес слова песни сей к Господу, " \
        "когда Господь избавил его от рук всех врагов его и от руки Саула. И он сказал:"
      )
      expect(index.dig("Psalms", 1, 1)).to eq("Блажен муж.")
      expect(index.dig("Psalms", 17, 1)).to be_nil
      expect(index.dig("Psalms", 17, 2)).to eq("Возлюблю Тебя, Господи, крепость моя!")
    end
  end

  it "normalizes RBS Russian chapter markers and stores chapter summaries as superscriptions" do
    text = <<~TEXT
      Библия. Синодальный перевод
      Ветхий Завет
      Пятикнижие
      Бытие
      Глава 1
      Сотворение неба и земли; 26  сотворение человека.
      1 В начале сотворил Бог небо и землю.
      2 Земля же была безвидна.
      Глава 2
      Бог благословляет седьмой день; 4  человек в раю Едемском.
      1 Так совершены небо и земля и все воинство их.
      2 И совершил Бог к седьмому дню дела Свои.
      Откровение
      Глава 1
      Иоанн пишет семи церквам.
      1 Откровение Иисуса Христа.
      Матфей рассказывает об Иисусе
      Глава 1
      1 Родословие Иисуса; 18 Его рождение.
      1 Родословие Иисуса Христа, Сына Давидова, Сына Авраамова.
      2 Авраам родил Исаака.
    TEXT

    with_text_file(text) do |path|
      result = described_class.from_file(path)
      index = Inamen::VerseIndex.build_chapter_index(result.lines)
      superscription_lines = result.lines.grep(/\A#{Regexp.escape(Inamen::LineClassifier::IMPORTED_SUPERSCRIPTION_PREFIX)}/)

      expect(result.books).to eq(["Genesis", "Revelation", "Matthew"])
      expect(result.language).to eq("ru")
      expect(result.lines).to include("CHAPTER 1", "CHAPTER 2")
      expect(index.dig("Genesis", 1, 1)).to eq("В начале сотворил Бог небо и землю.")
      expect(index.dig("Genesis", 2, 1)).to eq("Так совершены небо и земля и все воинство их.")
      expect(index.dig("Matthew", 1, 1)).to eq("Родословие Иисуса Христа, Сына Давидова, Сына Авраамова.")
      expect(superscription_lines).to include(
        "#{Inamen::LineClassifier::IMPORTED_SUPERSCRIPTION_PREFIX}Сотворение неба и земли; 26  сотворение человека.",
        "#{Inamen::LineClassifier::IMPORTED_SUPERSCRIPTION_PREFIX}Бог благословляет седьмой день; 4  человек в раю Едемском.",
        "#{Inamen::LineClassifier::IMPORTED_SUPERSCRIPTION_PREFIX}Иоанн пишет семи церквам.",
        "#{Inamen::LineClassifier::IMPORTED_SUPERSCRIPTION_PREFIX}1 Родословие Иисуса; 18 Его рождение."
      )
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
