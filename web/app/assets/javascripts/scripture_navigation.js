(function () {
  function pathFor(template, book, chapter) {
    return template
      .replace("__BOOK__", encodeURIComponent(book))
      .replace("__CHAPTER__", encodeURIComponent(chapter));
  }

  function replaceChapterOptions(select, chapters, selected) {
    select.innerHTML = "";
    chapters.forEach((chapter) => {
      const option = document.createElement("option");
      option.value = chapter;
      option.textContent = chapter;
      option.selected = String(chapter) === String(selected);
      select.appendChild(option);
    });
  }

  function init() {
    const bookSelect = document.getElementById("scripture-book-select");
    const chapterSelect = document.getElementById("scripture-chapter-select");
    if (!bookSelect || !chapterSelect) return;

    let chapterMap = {};
    try {
      chapterMap = JSON.parse(bookSelect.dataset.chapters || "{}");
    } catch (_error) {
      chapterMap = {};
    }

    const template = bookSelect.dataset.pathTemplate;
    if (!template) return;

    bookSelect.addEventListener("change", () => {
      const book = bookSelect.value;
      const chapters = chapterMap[book] || [1];
      replaceChapterOptions(chapterSelect, chapters, chapters[0]);
      window.location.assign(pathFor(template, book, chapters[0]));
    });

    chapterSelect.addEventListener("change", () => {
      window.location.assign(pathFor(template, bookSelect.value, chapterSelect.value));
    });
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
