(function () {
  const SCAN_DEBOUNCE_MS = 200;
  const PHRASE_FOCUS_KEY = "inamen:search-phrase-focus";

  let scanTimer = null;
  let pendingFocusInput = null;
  let mouseDownTarget = null;

  document.addEventListener("mousedown", (event) => {
    mouseDownTarget = event.target;
  });

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

  function rowExcluded(row) {
    if (!row) return false;
    const checkbox = row.querySelector('input[name$="[exclude]"]');
    return checkbox ? checkbox.checked : false;
  }

  function hasValidSearchTerms(discoveryForm) {
    const inputs = discoveryForm.querySelectorAll(".search-phrase-input");
    return Array.from(inputs).some((input) => {
      const row = input.closest("[data-search-phrase-row]");
      if (rowDisabled(row) || rowExcluded(row)) return false;
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
      (target.closest(".search-phrases-field") !== null ||
        target.closest(".search-phrase-options") !== null ||
        target.dataset.searchPhraseOption !== undefined)
    );
  }

  function focusTarget(element) {
    if (!(element instanceof HTMLElement)) return false;
    const panel = document.getElementById("search-phrases-panel");
    if (!panel || !panel.contains(element)) return false;
    if (element.closest(".search-phrase-options")) return true;
    if (element.classList.contains("search-phrase-input")) return true;
    if (element.closest("[data-search-phrase-row]")) return true;
    return false;
  }

  function focusMovedWithinPhrases(related) {
    return focusTarget(related);
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
      const exclude = row.querySelector('input[name$="[exclude]"]');
      if (!input) return;
      const flags = [
        caseSensitive && caseSensitive.checked ? "cs" : "ci",
        exclude && exclude.checked ? "ex" : null
      ]
        .filter(Boolean)
        .join(":");
      parts.push(`${flags}:${input.value}`);
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
    discoveryForm.dataset.scanPending = "true";
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

        const input = event.target;
        window.setTimeout(() => {
          const nextFocus = document.activeElement;
          const related = event.relatedTarget || mouseDownTarget;
          if (focusMovedWithinPhrases(related) || focusMovedWithinPhrases(nextFocus)) return;
          if (input instanceof HTMLInputElement && input.classList.contains("search-phrase-input")) {
            scheduleScan(discoveryForm);
          }
        }, 0);
      },
      true
    );

    discoveryForm.addEventListener("change", (event) => {
      if (!isPhraseCheckbox(event.target)) return;
      cancelScheduledScan();
      scheduleScan(discoveryForm);
    });

    discoveryForm.addEventListener("submit", () => {
      if (discoveryForm.dataset.scanPending !== "true") return;
      delete discoveryForm.dataset.scanPending;
      markScanned(discoveryForm);
    });

    document.addEventListener("discovery:phrase-validity-changed", () => {
      const results = document.querySelector("[data-discovery-results]");
      if (!results) return;
      if (discoveryForm.dataset.resultsReady === "true") {
        results.hidden = false;
        return;
      }
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

    initAutoScan(discoveryForm);
  }

  function initAutoScan(discoveryForm) {
    if (discoveryForm.dataset.autoScan !== "true") return;
    if (discoveryForm.dataset.resultsReady === "true") return;

    const tryAutoScan = () => {
      if (!canScan(discoveryForm)) return false;
      cancelScheduledScan();
      scheduleScan(discoveryForm);
      return true;
    };

    if (tryAutoScan()) return;

    document.addEventListener("discovery:phrase-validity-changed", function onValidity() {
      if (tryAutoScan()) {
        document.removeEventListener("discovery:phrase-validity-changed", onValidity);
      }
    });
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
