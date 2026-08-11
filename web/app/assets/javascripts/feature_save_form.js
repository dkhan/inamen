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

    // Actual reflects the currently selected measure's total. Expected defaults
    // to the same number, but stays editable so a feature can intentionally save
    // a different target value.
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
