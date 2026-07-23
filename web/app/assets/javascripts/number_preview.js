(function () {
  const SHOW_DELAY = 180;
  const cache = new Map();
  let popup = null;
  let activeLink = null;
  let hoverTimer = null;
  let requestToken = 0;

  function ensurePopup() {
    if (popup) return popup;

    popup = document.createElement("div");
    popup.className = "number-preview";
    popup.hidden = true;
    popup.setAttribute("role", "tooltip");
    document.body.appendChild(popup);
    return popup;
  }

  function numberLinks() {
    return document.querySelectorAll("[data-number-preview-url]");
  }

  function show(link) {
    clearTimeout(hoverTimer);
    hoverTimer = window.setTimeout(() => loadAndRender(link), SHOW_DELAY);
  }

  function hide(link) {
    clearTimeout(hoverTimer);
    if (link && activeLink && link !== activeLink) return;

    activeLink = null;
    if (popup) popup.hidden = true;
  }

  async function loadAndRender(link) {
    const url = link.dataset.numberPreviewUrl;
    if (!url) return;

    activeLink = link;
    const token = ++requestToken;
    const box = ensurePopup();
    box.hidden = false;
    box.innerHTML = '<div class="number-preview-muted">Loading…</div>';
    positionPopup(link, box);

    try {
      const data = cache.has(url) ? cache.get(url) : await fetchPreview(url);
      if (token !== requestToken || activeLink !== link) return;

      renderPreview(box, data);
      positionPopup(link, box);
    } catch (_error) {
      if (token !== requestToken || activeLink !== link) return;

      box.innerHTML = '<div class="number-preview-muted">Preview unavailable</div>';
      positionPopup(link, box);
    }
  }

  async function fetchPreview(url) {
    const response = await fetch(url, { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error("Preview request failed");

    const data = await response.json();
    cache.set(url, data);
    return data;
  }

  function renderPreview(box, data) {
    const seven = (data.seven_forms || []).slice(0, 5).map((line) => `<li>${escapeHtml(line)}</li>`).join("");
    const indexes = (data.prime_indexes || []).map((line) => `<li>${escapeHtml(line)}</li>`).join("");

    box.innerHTML = `
      <div class="number-preview-title">${escapeHtml(data.title || data.number)}</div>
      <dl class="number-preview-facts">
        <dt>Prime factors</dt>
        <dd>${escapeHtml(data.factorization || "—")}</dd>
      </dl>
      <div class="number-preview-section">
        <div class="number-preview-heading">Prime indexes</div>
        <ul>${indexes}</ul>
      </div>
      <div class="number-preview-section">
        <div class="number-preview-heading">Seven-fold forms</div>
        <ul>${seven}</ul>
      </div>
    `;
  }

  function positionPopup(link, box) {
    const rect = link.getBoundingClientRect();
    const margin = 10;
    const width = Math.min(320, window.innerWidth - margin * 2);
    box.style.width = `${width}px`;

    const popupRect = box.getBoundingClientRect();
    let left = rect.left + window.scrollX;
    let top = rect.bottom + window.scrollY + 8;

    left = Math.min(left, window.scrollX + window.innerWidth - popupRect.width - margin);
    left = Math.max(left, window.scrollX + margin);

    if (top + popupRect.height > window.scrollY + window.innerHeight - margin) {
      top = rect.top + window.scrollY - popupRect.height - 8;
    }
    top = Math.max(top, window.scrollY + margin);

    box.style.left = `${left}px`;
    box.style.top = `${top}px`;
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function bind() {
    numberLinks().forEach((link) => {
      if (link.dataset.numberPreviewBound) return;

      link.dataset.numberPreviewBound = "true";
      link.addEventListener("mouseenter", () => show(link));
      link.addEventListener("mouseleave", () => hide(link));
      link.addEventListener("focus", () => show(link));
      link.addEventListener("blur", () => hide(link));
    });
  }

  document.addEventListener("DOMContentLoaded", bind);
  document.addEventListener("turbo:load", bind);
})();
