(function () {
  function parseCounts(stats) {
    try {
      return JSON.parse(stats.dataset.featureCounts) || {};
    } catch (_error) {
      return {};
    }
  }

  function init() {
    const select = document.querySelector("[data-feature-unit-select]");
    const stats = document.querySelector("[data-feature-counts]");
    if (!select || !stats) return;

    const counts = parseCounts(stats);
    const actualField = document.querySelector("[data-feature-actual-field]");
    const expectedField = document.querySelector("[data-feature-expected-field]");
    const unitLabels = document.querySelectorAll("[data-feature-unit-label]");

    // Actual and Expected are read-only and always reflect the currently selected
    // measure's total. Switching the measure updates them from the already-loaded
    // search results, without re-running the search, so only the last-selected
    // values are submitted.
    function apply() {
      const unit = select.value;
      const count = Object.prototype.hasOwnProperty.call(counts, unit) ? counts[unit] : 0;

      if (actualField) actualField.value = count;
      if (expectedField) expectedField.value = count;
      unitLabels.forEach((label) => {
        label.textContent = unit;
      });
    }

    select.addEventListener("change", apply);
    apply();
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
