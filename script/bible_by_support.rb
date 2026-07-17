# frozen_string_literal: true

require "pathname"

module BibleBySupport
  Book = Struct.new(:id, :title, :chapters, keyword_init: true)

  ROOT = Pathname(__dir__).join("..").expand_path

  BOOKS = [
    ["Бытие", 50],
    ["Исход", 40],
    ["Левит", 27],
    ["Числа", 36],
    ["Второзаконие", 34],
    ["Книга Иисуса Навина", 24],
    ["Книга судей Израилевых", 21],
    ["Книга Руфи", 4],
    ["1-я книга Царств", 31],
    ["2-я книга Царств", 24],
    ["3-я книга Царств", 22],
    ["4-я книга Царств", 25],
    ["1-я книга Паралипоменон", 29],
    ["2-я книга Паралипоменон", 36],
    ["Книга Ездры", 10],
    ["Книга Неемии", 13],
    ["Книга Есфири", 10],
    ["Книга Иова", 42],
    ["Псалмы", 150],
    ["Книга притчей Соломоновых", 31],
    ["Книга Екклесиаста, или проповедника", 12],
    ["Песнь песней", 8],
    ["Книга Исайи", 66],
    ["Книга Иеремии", 52],
    ["Книга плача Иеремии", 5],
    ["Книга Иезекииля", 48],
    ["Книга Даниила", 12],
    ["Книга Осии", 14],
    ["Книга Иоиля", 3],
    ["Книга Амоса", 9],
    ["Книга Авдия", 1],
    ["Книга Ионы", 4],
    ["Книга Михея", 7],
    ["Книга Наума", 3],
    ["Книга Аввакума", 3],
    ["Книга Софонии", 3],
    ["Книга Аггея", 2],
    ["Книга Захарии", 14],
    ["Книга Малахии", 4],
    ["Матфей рассказывает об Иисусе", 28],
    ["Марк рассказывает об Иисусе", 16],
    ["Лука рассказывает об Иисусе", 24],
    ["Иоанн рассказывает об Иисусе", 21],
    ["Деяния апостолов", 28],
    ["Иакова", 5],
    ["1-е Петра", 5],
    ["2-е Петра", 3],
    ["1-е Иоанна", 5],
    ["2-е Иоанна", 1],
    ["3-е Иоанна", 1],
    ["Иуды", 1],
    ["Римлянам", 16],
    ["1-е Коринфянам", 16],
    ["2-е Коринфянам", 13],
    ["Галатам", 6],
    ["Ефесянам", 6],
    ["Филиппийцам", 4],
    ["Колоссянам", 4],
    ["1-е Фессалоникийцам", 5],
    ["2-е Фессалоникийцам", 3],
    ["1-е Тимофею", 6],
    ["2-е Тимофею", 4],
    ["Титу", 3],
    ["Филимону", 1],
    ["Евреям", 13],
    ["Откровение", 22]
  ].each_with_index.map { |(title, chapters), index| Book.new(id: index + 1, title: title, chapters: chapters) }.freeze

  module_function

  def validate_version!(version)
    return version if version.match?(/\A[a-z0-9_-]+\z/)

    raise ArgumentError, "Version must contain only lowercase letters, digits, underscores, or hyphens: #{version.inspect}"
  end

  def cache_dir(version)
    ROOT.join("tmp", "bible_by", version).to_s
  end

  def default_output(version)
    filename = version == "syn" ? "RUSSIAN_SYNODAL_BIBLE_BY.txt" : "BIBLE_BY_#{version.upcase.tr("-", "_")}.txt"
    ROOT.join("data", filename).to_s
  end

  def base_url(version)
    "https://bible.by/#{version}"
  end

  def chapter_url(version, book_id, chapter)
    "#{base_url(version)}/#{book_id}/#{chapter}/"
  end
end
