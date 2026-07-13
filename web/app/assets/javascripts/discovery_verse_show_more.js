(function () {
  function updateButton(button, remaining, offset) {
    if (remaining <= 0) {
      button.closest(".discovery-verse-more")?.remove();
      return;
    }

    button.disabled = false;
    button.dataset.offset = String(offset);
    button.dataset.remaining = String(remaining);
    button.textContent = `Show more (${remaining.toLocaleString()})`;

    const url = new URL(button.dataset.moreUrl, window.location.origin);
    url.searchParams.set("offset", String(offset));
    button.dataset.moreUrl = `${url.pathname}${url.search}`;
  }

  async function loadMore(button) {
    const list = button.closest(".discovery-verse-results")?.querySelector(".discovery-verse-list");
    if (!list) return;

    const offset = Number.parseInt(button.dataset.offset || "0", 10);
    const remaining = Number.parseInt(button.dataset.remaining || "0", 10);
    const url = button.dataset.moreUrl;
    if (!url || remaining <= 0) return;

    button.disabled = true;
    button.textContent = "Loading…";

    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" }
      });
      if (!response.ok) throw new Error("request failed");

      const html = await response.text();
      list.insertAdjacentHTML("beforeend", html);

      const loaded = (html.match(/discovery-verse-item/g) || []).length;
      const nextOffset = offset + loaded;
      const nextRemaining = Math.max(remaining - loaded, 0);
      updateButton(button, nextRemaining, nextOffset);
    } catch (_error) {
      button.disabled = false;
      button.textContent = `Show more (${remaining.toLocaleString()})`;
    }
  }

  function init() {
    document.addEventListener("click", (event) => {
      const button = event.target.closest(".discovery-verse-show-more");
      if (!button) return;

      event.preventDefault();
      loadMore(button);
    });
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
