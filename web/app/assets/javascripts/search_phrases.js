(function () {
  const PHRASE_FOCUS_KEY = "inamen:search-phrase-focus";

  function panel() {
    return document.getElementById("search-phrases-panel");
  }

  function list(root) {
    return root.querySelector("[data-search-phrases-list]");
  }

  function rows(root) {
    return Array.from(list(root).querySelectorAll("[data-search-phrase-row]"));
  }

  function templateHtml() {
    const template = document.getElementById("search-phrase-row-template");
    return template ? template.innerHTML.trim() : "";
  }

  function nextIndex(root) {
    const indices = rows(root).map((row) => {
      const input = row.querySelector(".search-phrase-input");
      const match = input && input.name.match(/search_phrases\[(\d+)\]/);
      return match ? Number.parseInt(match[1], 10) : 0;
    });
    return indices.length === 0 ? 0 : Math.max(...indices) + 1;
  }

  function rowFromTemplate(root, index) {
    const html = templateHtml().replaceAll("__INDEX__", String(index));
    const wrapper = document.createElement("div");
    wrapper.innerHTML = html;
    return wrapper.firstElementChild;
  }

  function phraseInputForIndex(root, index) {
    return root.querySelector(`input[name="search_phrases[${index}][phrase]"]`);
  }

  function restorePhraseFocus(root) {
    let saved = null;
    try {
      const raw = sessionStorage.getItem(PHRASE_FOCUS_KEY);
      saved = raw ? JSON.parse(raw) : null;
    } catch (_error) {
      saved = null;
    }
    if (!saved) return;

    sessionStorage.removeItem(PHRASE_FOCUS_KEY);

    const input = phraseInputForIndex(root, saved.index) || rows(root).at(-1)?.querySelector(".search-phrase-input");
    if (!input) return;

    requestAnimationFrame(() => {
      input.focus();
      if (typeof saved.start === "number" && typeof saved.end === "number") {
        const end = Math.min(saved.end, input.value.length);
        const start = Math.min(saved.start, end);
        input.setSelectionRange(start, end);
      }
    });
  }

  function setRowDisabled(row, disabled) {
    if (disabled) {
      row.setAttribute("data-disabled", "");
    } else {
      row.removeAttribute("data-disabled");
    }
  }

  function bindRow(root, row) {
    const clearButton = row.querySelector("[data-clear-phrase]");
    const removeButton = row.querySelector("[data-remove-phrase]");
    const disableCheckbox = row.querySelector("[data-search-phrase-disable]");
    const input = row.querySelector(".search-phrase-input");

    if (disableCheckbox) {
      setRowDisabled(row, disableCheckbox.checked);
      disableCheckbox.addEventListener("change", () => {
        setRowDisabled(row, disableCheckbox.checked);
      });
    }

    if (clearButton && input) {
      clearButton.addEventListener("mousedown", (event) => event.preventDefault());
      clearButton.addEventListener("click", () => {
        input.value = "";
        input.focus();
        document.dispatchEvent(new CustomEvent("discovery:schedule-scan"));
      });
    }

    if (removeButton) {
      removeButton.addEventListener("mousedown", (event) => event.preventDefault());
      removeButton.addEventListener("click", () => {
        if (rows(root).length <= 1) {
          if (input) input.value = "";
          document.dispatchEvent(new CustomEvent("discovery:schedule-scan"));
          return;
        }
        row.remove();
        reindexRows(root);
        document.dispatchEvent(new CustomEvent("discovery:schedule-scan"));
      });
    }
  }

  function reindexRows(root) {
    rows(root).forEach((row, index) => {
      row.querySelectorAll("[name^='search_phrases[']").forEach((field) => {
        field.name = field.name.replace(/search_phrases\[\d+\]/, `search_phrases[${index}]`);
      });
    });
  }

  function addRow(root) {
    const row = rowFromTemplate(root, nextIndex(root));
    list(root).appendChild(row);
    bindRow(root, row);
    document.dispatchEvent(new CustomEvent("discovery:search-phrase-row-added", { detail: { row } }));
    const input = row.querySelector(".search-phrase-input");
    if (input) input.focus();
  }

  function init() {
    const root = panel();
    if (!root) return;

    rows(root).forEach((row) => bindRow(root, row));

    const addButton = document.getElementById("add-search-phrase");
    if (addButton) {
      addButton.addEventListener("mousedown", (event) => event.preventDefault());
      addButton.addEventListener("click", () => {
        document.dispatchEvent(new CustomEvent("discovery:cancel-scan"));
        addRow(root);
      });
    }

    restorePhraseFocus(root);
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
