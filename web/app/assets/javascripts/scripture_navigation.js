(function () {
  function pathFor(template, book, chapter, edition) {
    return template
      .replace("__BOOK__", encodeURIComponent(book))
      .replace("__CHAPTER__", encodeURIComponent(chapter))
      .replace("__EDITION__", encodeURIComponent(edition));
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
    const editionSelect = document.getElementById("scripture-edition-select");
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

    function selectedEdition() {
      return editionSelect ? editionSelect.value : "";
    }

    if (editionSelect) {
      editionSelect.addEventListener("change", () => {
        window.location.assign(pathFor(template, bookSelect.value, chapterSelect.value, selectedEdition()));
      });
    }

    bookSelect.addEventListener("change", () => {
      const book = bookSelect.value;
      const chapters = chapterMap[book] || [1];
      replaceChapterOptions(chapterSelect, chapters, chapters[0]);
      window.location.assign(pathFor(template, book, chapters[0], selectedEdition()));
    });

    chapterSelect.addEventListener("change", () => {
      window.location.assign(pathFor(template, bookSelect.value, chapterSelect.value, selectedEdition()));
    });
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
