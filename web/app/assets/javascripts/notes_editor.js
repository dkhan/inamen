(function () {
  function wrapSelection(textarea, before, after, placeholder) {
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const value = textarea.value;
    const selected = value.slice(start, end);
    const inner = selected || placeholder;
    const replacement = `${before}${inner}${after}`;
    textarea.setRangeText(replacement, start, end, "select");
    const cursorStart = start + before.length;
    const cursorEnd = cursorStart + inner.length;
    textarea.setSelectionRange(cursorStart, cursorEnd);
    textarea.focus();
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
  }

  function applyBulletList(textarea) {
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const value = textarea.value;
    const selected = value.slice(start, end);
    const block = selected || "item";
    const lines = block.split("\n");
    const formatted = lines
      .map((line) => (line.match(/^\s*-\s+/) ? line : `- ${line}`))
      .join("\n");

    textarea.setRangeText(formatted, start, end, "select");
    textarea.setSelectionRange(start, start + formatted.length);
    textarea.focus();
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
  }

  function initNotesEditor(root) {
    const textarea = root.querySelector("[data-notes-editor-target]");
    const toolbar = root.querySelector("[data-notes-editor-toolbar]");
    if (!textarea || !toolbar) return;

    toolbar.addEventListener("click", (event) => {
      const button = event.target.closest("[data-format]");
      if (!button || button.disabled) return;

      event.preventDefault();
      const format = button.dataset.format;

      switch (format) {
        case "bold":
          wrapSelection(textarea, "**", "**", "bold");
          break;
        case "italic":
          wrapSelection(textarea, "*", "*", "italic");
          break;
        case "strike":
          wrapSelection(textarea, "~~", "~~", "strike");
          break;
        case "bullet":
          applyBulletList(textarea);
          break;
        default:
          break;
      }
    });
  }

  function init() {
    document.querySelectorAll("[data-notes-editor]").forEach(initNotesEditor);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
