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

  function hasValidSearchTerms(discoveryForm) {
    const inputs = discoveryForm.querySelectorAll(".search-phrase-input");
    return Array.from(inputs).some((input) => {
      const row = input.closest("[data-search-phrase-row]");
      if (rowDisabled(row)) return false;
      if (input.value.trim() === "") return false;
      return row.dataset.canSearch === "true";
    });
  }

  function canScan(discoveryForm) {
    if (isWordCountMode(discoveryForm)) return hasValidSearchTerms(discoveryForm);
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

  function scopeFingerprint(discoveryForm) {
    const panel = discoveryForm.querySelector("#search-within-panel");
    if (!panel) return "";

    const books = [];
    panel.querySelectorAll(".search-within-book-leaf").forEach((input) => {
      if (input.checked) books.push(input.value);
    });
    books.sort();

    const colophons = panel.querySelector("#search_selection_colophons");
    const superscriptions = panel.querySelector("#search_selection_superscriptions");

    return JSON.stringify({
      colophons: colophons ? colophons.checked : false,
      superscriptions: superscriptions ? superscriptions.checked : false,
      books
    });
  }

  function phraseFingerprint(discoveryForm) {
    const parts = [];
    discoveryForm.querySelectorAll("[data-search-phrase-row]").forEach((row) => {
      if (rowDisabled(row)) return;
      const input = row.querySelector(".search-phrase-input");
      const caseSensitive = row.querySelector('input[name$="[case_sensitive]"]');
      if (!input) return;
      parts.push(`${caseSensitive && caseSensitive.checked ? "cs:" : "ci:"}${input.value}`);
    });
    return parts.join("\n");
  }

  function scanFingerprint(discoveryForm) {
    return `${phraseFingerprint(discoveryForm)}\n${scopeFingerprint(discoveryForm)}`;
  }

  function markScanned(discoveryForm) {
    discoveryForm.dataset.lastScannedPhrase = scanFingerprint(discoveryForm);
  }

  function shouldScan(discoveryForm) {
    if (!canScan(discoveryForm)) return false;
    return scanFingerprint(discoveryForm) !== discoveryForm.dataset.lastScannedPhrase;
  }

  function runScan(discoveryForm) {
    const scanAction = discoveryForm.getAttribute("data-scan-action");
    if (!scanAction || !shouldScan(discoveryForm)) return;

    if (pendingFocusInput) {
      rememberPhraseFocus(pendingFocusInput);
      pendingFocusInput = null;
    }

    discoveryForm.action = scanAction;
    discoveryForm.method = "post";
    discoveryForm.requestSubmit();
    markScanned(discoveryForm);
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

    document.addEventListener("discovery:phrase-validity-changed", () => {
      const results = document.querySelector("[data-discovery-results]");
      if (!results) return;
      results.hidden = !canScan(discoveryForm);
    });

    document.addEventListener("discovery:schedule-scan", () => {
      scheduleScan(discoveryForm);
    });

    document.addEventListener("discovery:cancel-scan", () => {
      cancelScheduledScan();
    });

    if (discoveryForm.dataset.resultsReady === "true") {
      markScanned(discoveryForm);
    }
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
