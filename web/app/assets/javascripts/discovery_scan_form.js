(function () {
  const SCAN_DEBOUNCE_MS = 200;
  const PHRASE_FOCUS_KEY = "inamen:search-phrase-focus";

  let scanTimer = null;
  let pendingFocusInput = null;

  function form() {
    return document.getElementById("discovery-filters-form");
  }

  function isWordCountMode(discoveryForm) {
    return discoveryForm.querySelector("#search-phrases-panel") !== null;
  }

  function rowDisabled(row) {
    if (!row) return false;
    const checkbox = row.querySelector("[data-search-phrase-disable]");
    return checkbox ? checkbox.checked : false;
  }

  function hasSearchTerms(discoveryForm) {
    const inputs = discoveryForm.querySelectorAll(".search-phrase-input");
    return Array.from(inputs).some((input) => {
      const row = input.closest("[data-search-phrase-row]");
      if (rowDisabled(row)) return false;
      return input.value.trim() !== "";
    });
  }

  function canScan(discoveryForm) {
    if (isWordCountMode(discoveryForm)) return hasSearchTerms(discoveryForm);
    return true;
  }

  function isScanField(target) {
    if (!(target instanceof HTMLElement)) return false;
    if (target.closest(".discovery-search-within")) return false;
    if (target.tagName === "BUTTON" || target.tagName === "SELECT") return false;

    return (
      target.classList.contains("search-phrase-input") ||
      (target.closest(".discovery-filters") !== null &&
        (target.type === "number" || target.classList.contains("search-phrase-input")))
    );
  }

  function isPhraseCheckbox(target) {
    return (
      target instanceof HTMLInputElement &&
      target.type === "checkbox" &&
      target.closest(".search-phrases-field") !== null
    );
  }

  function focusMovedWithinPhrases(related) {
    if (!(related instanceof HTMLElement)) return false;
    const panel = document.getElementById("search-phrases-panel");
    return panel ? panel.contains(related) : false;
  }

  function cancelScheduledScan() {
    clearTimeout(scanTimer);
    scanTimer = null;
    pendingFocusInput = null;
  }

  function rememberPhraseFocus(input) {
    if (!(input instanceof HTMLInputElement) || !input.classList.contains("search-phrase-input")) {
      return;
    }

    const match = input.name.match(/search_phrases\[(\d+)\]/);
    if (!match) return;

    sessionStorage.setItem(
      PHRASE_FOCUS_KEY,
      JSON.stringify({
        index: Number.parseInt(match[1], 10),
        start: input.selectionStart ?? input.value.length,
        end: input.selectionEnd ?? input.value.length
      })
    );
  }

  function runScan(discoveryForm) {
    const scanAction = discoveryForm.getAttribute("data-scan-action");
    if (!scanAction || !canScan(discoveryForm)) return;

    if (pendingFocusInput) {
      rememberPhraseFocus(pendingFocusInput);
      pendingFocusInput = null;
    }

    discoveryForm.action = scanAction;
    discoveryForm.method = "post";
    discoveryForm.requestSubmit();
  }

  function scheduleScan(discoveryForm, options = {}) {
    if (options.rememberFocus) {
      pendingFocusInput = options.trigger ?? null;
    }

    clearTimeout(scanTimer);
    scanTimer = setTimeout(() => {
      scanTimer = null;
      runScan(discoveryForm);
    }, SCAN_DEBOUNCE_MS);
  }

  function init() {
    const discoveryForm = form();
    if (!discoveryForm) return;

    discoveryForm.addEventListener("keydown", (event) => {
      if (event.key !== "Enter") return;
      if (!isScanField(event.target)) return;

      event.preventDefault();
      scheduleScan(discoveryForm, { rememberFocus: true, trigger: event.target });
    });

    discoveryForm.addEventListener(
      "focusout",
      (event) => {
        if (!isScanField(event.target)) return;
        if (focusMovedWithinPhrases(event.relatedTarget)) return;
        scheduleScan(discoveryForm);
      },
      true
    );

    discoveryForm.addEventListener("change", (event) => {
      if (!isPhraseCheckbox(event.target)) return;
      scheduleScan(discoveryForm);
    });

    document.addEventListener("discovery:schedule-scan", () => {
      scheduleScan(discoveryForm);
    });

    document.addEventListener("discovery:cancel-scan", () => {
      cancelScheduledScan();
    });
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
