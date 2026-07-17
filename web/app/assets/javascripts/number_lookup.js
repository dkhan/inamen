(function () {
  function bindInput(input) {
    if (!input || input.dataset.numberLookupBound === "true") return;
    input.dataset.numberLookupBound = "true";

    input.addEventListener("dblclick", () => {
      input.select();
    });

    input.addEventListener("focus", () => {
      input.setSelectionRange(input.value.length, input.value.length);
    });
  }

  function init() {
    document.querySelectorAll("[data-number-lookup-input]").forEach((input) => {
      bindInput(input);
      const form = input.closest("form");
      if (!form || form.dataset.numberLookupFormBound === "true") return;

      form.dataset.numberLookupFormBound = "true";
      form.addEventListener("submit", () => {
        input.value = input.value.replace(/,/g, "").trim();
      });
    });
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
