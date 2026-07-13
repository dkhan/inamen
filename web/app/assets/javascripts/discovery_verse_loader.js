(function () {
  const POLL_MS = 400;

  function container() {
    return document.getElementById("discovery-verse-results");
  }

  function versesReady(node) {
    return node.querySelector("[data-verses-ready]") !== null;
  }

  async function loadVerses() {
    const root = container();
    if (!root) return;

    const url = root.dataset.versesUrl;
    if (!url) return;
    if (versesReady(root)) return;

    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" }
      });
      const html = await response.text();
      root.innerHTML = html;

      if (!versesReady(root)) {
        window.setTimeout(loadVerses, POLL_MS);
      }
    } catch (_error) {
      window.setTimeout(loadVerses, POLL_MS);
    }
  }

  function init() {
    if (container()) {
      loadVerses();
    }
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
