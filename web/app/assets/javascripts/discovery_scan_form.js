(function () {
  const SCAN_DEBOUNCE_MS = 200;

  let scanTimer = null;
  let pendingFocusInput = null;

  function form() {
    return document.getElementById("discovery-filters-form");
  }

  function isBusy(discoveryForm) {
    return discoveryForm.dataset.scanBusy === "true";
  }

  function busyControls(discoveryForm) {
    const controls = Array.from(
      discoveryForm.querySelectorAll("input, select, textarea, button")
    );
    const edition = document.getElementById("edition");
    if (edition) controls.push(edition);
    return controls;
  }

  function isTextEntry(el) {
    if (el.tagName === "TEXTAREA") return true;
    if (el.tagName !== "INPUT") return false;
    return ["text", "search", "number", "email", "url", "tel", "password"].includes(el.type);
  }

  // Lock every control read-only while a scan is running and until results and
  // verses have loaded. Text inputs use readOnly (still submitted); other
  // controls are disabled.
  function setBusy(discoveryForm, busy) {
    if (busy) {
      discoveryForm.dataset.scanBusy = "true";
    } else {
      delete discoveryForm.dataset.scanBusy;
    }
    discoveryForm.setAttribute("aria-busy", busy ? "true" : "false");
    busyControls(discoveryForm).forEach((el) => {
      if (el.type === "hidden") return;
      if (isTextEntry(el)) {
        el.readOnly = busy;
      } else {
        el.disabled = busy;
      }
    });
  }

  // On (re)load, lock the form when the page is still computing counts or when
  // verse matches are still being fetched; unlock once everything is ready.
  function refreshBusyFromPage(discoveryForm) {
    if (discoveryForm.dataset.status === "computing") {
      setBusy(discoveryForm, true);
      return;
    }
    const verses = document.getElementById("discovery-verse-results");
    if (verses && !verses.querySelector("[data-verses-ready]")) {
      setBusy(discoveryForm, true);
      return;
    }
    setBusy(discoveryForm, false);
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

  function cancelScheduledScan() {
    clearTimeout(scanTimer);
    scanTimer = null;
    pendingFocusInput = null;
  }

  function rememberPhraseFocus(input) {
    document.dispatchEvent(new CustomEvent("discovery:save-phrase-focus", { detail: { input } }));
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
      const input = row.querySelector(".search-phrase-input");
      const caseSensitive = row.querySelector('input[name$="[case_sensitive]"]');
      const exclude = row.querySelector('input[name$="[exclude]"]');
      const disable = row.querySelector("[data-search-phrase-disable]");
      if (!input) return;
      const flags = [
        caseSensitive && caseSensitive.checked ? "cs" : "ci",
        exclude && exclude.checked ? "ex" : null,
        disable && disable.checked ? "dis" : null
      ]
        .filter(Boolean)
        .join(":");
      parts.push(`${flags}:${input.value}`);
    });
    return parts.join("\n");
  }

  function filterFingerprint(discoveryForm) {
    const fieldValue = (name) => {
      const field = discoveryForm.querySelector(`[name="${name}"]`);
      return field ? field.value : "";
    };

    return JSON.stringify({
      mode: fieldValue("mode"),
      divisibleBy: fieldValue("divisible_by"),
      minCount: fieldValue("min_count"),
      minGroupSize: fieldValue("min_group_size"),
      matchBy: fieldValue("match_by")
    });
  }

  function scanFingerprint(discoveryForm) {
    return `${filterFingerprint(discoveryForm)}\n${phraseFingerprint(discoveryForm)}\n${scopeFingerprint(discoveryForm)}`;
  }

  function markScanned(discoveryForm) {
    discoveryForm.dataset.lastScannedPhrase = scanFingerprint(discoveryForm);
  }

  function shouldScan(discoveryForm) {
    if (!canScan(discoveryForm)) return false;
    return scanFingerprint(discoveryForm) !== discoveryForm.dataset.lastScannedPhrase;
  }

  function runScan(discoveryForm, options = {}) {
    const scanAction = discoveryForm.getAttribute("data-scan-action");
    if (!canScan(discoveryForm)) {
      const results = document.querySelector("[data-discovery-results]");
      if (results) results.hidden = true;
      return;
    }
    if (!scanAction || (!options.force && !shouldScan(discoveryForm))) return;

    if (pendingFocusInput) {
      document.dispatchEvent(
        new CustomEvent("discovery:save-phrase-focus", { detail: { input: pendingFocusInput } })
      );
      pendingFocusInput = null;
    } else {
      document.dispatchEvent(new CustomEvent("discovery:save-phrase-focus"));
    }

    discoveryForm.action = scanAction;
    discoveryForm.method = "post";
    discoveryForm.dataset.scanPending = "true";
    discoveryForm.requestSubmit();
    // requestSubmit() has already serialized the form data synchronously, so it
    // is safe to lock the controls now for immediate read-only feedback.
    setBusy(discoveryForm, true);
  }

  function scheduleScan(discoveryForm, options = {}) {
    if (isBusy(discoveryForm)) return;
    if (options.rememberFocus || options.trigger) {
      pendingFocusInput = options.trigger ?? pendingFocusInput;
    }

    clearTimeout(scanTimer);
    scanTimer = setTimeout(() => {
      scanTimer = null;
      runScan(discoveryForm, options);
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

    discoveryForm.addEventListener("change", (event) => {
      if (!isPhraseCheckbox(event.target)) return;
      cancelScheduledScan();
      scheduleScan(discoveryForm, { force: true });
    });

    discoveryForm.addEventListener("submit", () => {
      if (discoveryForm.dataset.scanPending !== "true") return;
      delete discoveryForm.dataset.scanPending;
      markScanned(discoveryForm);
    });

    document.addEventListener("discovery:phrase-validity-changed", () => {
      const results = document.querySelector("[data-discovery-results]");
      if (!results) return;
      results.hidden = !canScan(discoveryForm) || shouldScan(discoveryForm);
    });

    document.addEventListener("discovery:schedule-scan", (event) => {
      scheduleScan(discoveryForm, event.detail || {});
    });

    document.addEventListener("discovery:cancel-scan", () => {
      cancelScheduledScan();
    });

    document.addEventListener("discovery:verses-loaded", () => {
      setBusy(discoveryForm, false);
    });

    if (discoveryForm.dataset.resultsReady === "true") {
      markScanned(discoveryForm);
    }

    refreshBusyFromPage(discoveryForm);
  }

  function restoreAfterHistoryNavigation() {
    const discoveryForm = form();
    if (!discoveryForm) return;

    cancelScheduledScan();
    delete discoveryForm.dataset.scanPending;

    if (discoveryForm.dataset.resultsReady === "true") {
      markScanned(discoveryForm);
    }

    refreshBusyFromPage(discoveryForm);
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
  window.addEventListener("pageshow", restoreAfterHistoryNavigation);
})();
