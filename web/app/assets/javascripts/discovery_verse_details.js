(function () {
  function dialog() {
    return document.getElementById("verse-details-dialog");
  }

  function body() {
    return document.querySelector("[data-verse-details-body]");
  }

  function formatLine(label, value) {
    return `<div class="verse-details-line"><span class="verse-details-label">${label}</span><span>${value}</span></div>`;
  }

  function renderDetails(details) {
    const lines = [
      formatLine("Reference", `(${details.occurrence_in_search}) ${details.reference} [${details.occurrence_in_verse}]`),
      formatLine("Occurrence", `${details.occurrence_in_search} of ${details.occurrences_in_search}`),
      formatLine("Book", `${details.book_number} of ${details.total_books}`),
      formatLine(
        "Chapter",
        details.nt_chapter_number
          ? `${details.chapter_number} of ${details.total_chapters} / ${details.nt_chapter_number} of ${details.nt_total_chapters}`
          : `${details.chapter_number} of ${details.total_chapters}`
      ),
      formatLine(
        "Verse",
        details.nt_verse_number
          ? `${details.verse_number} of ${details.total_verses} / ${details.nt_verse_number} of ${details.nt_total_verses}`
          : `${details.verse_number} of ${details.total_verses}`
      ),
      formatLine("Word position", `${details.word_index}${details.word_count > 1 ? ` (${details.word_count} words)` : ""}`),
      formatLine("Search within", details.scope_label)
    ];

    body().innerHTML = lines.join("");
    document.getElementById("verse-details-title").textContent = `Details — ${details.reference}`;
  }

  function openDialog(details) {
    const node = dialog();
    if (!node) return;

    renderDetails(details);
    node.hidden = false;
  }

  function closeDialog() {
    const node = dialog();
    if (!node) return;

    node.hidden = true;
  }

  function init() {
    document.addEventListener("click", (event) => {
      const button = event.target.closest("[data-verse-details]");
      if (button) {
        event.preventDefault();
        try {
          const details = JSON.parse(button.getAttribute("data-verse-details"));
          openDialog(details);
        } catch (_error) {
          return;
        }
        return;
      }

      if (event.target.closest("[data-close-verse-details]")) {
        closeDialog();
      }
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") closeDialog();
    });
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
