(function () {
  const STORAGE_KEY = "inamen:search-within-expanded";

  function panel() {
    return document.getElementById("search-within-panel");
  }

  function leafInputs(root) {
    return Array.from(root.querySelectorAll(".search-within-leaf"));
  }

  function bookLeaves(root) {
    return Array.from(root.querySelectorAll(".search-within-book-leaf"));
  }

  function childLeaves(branch) {
    const childList = branch.querySelector(":scope > .search-within-children");
    if (!childList) return [];
    return Array.from(childList.querySelectorAll(".search-within-book-leaf"));
  }

  function parentBranches(root) {
    return Array.from(root.querySelectorAll(".search-within-branch"));
  }

  function branchId(branch) {
    return branch.getAttribute("data-branch-id");
  }

  function readExpandedState() {
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (_error) {
      return null;
    }
  }

  function writeExpandedState(root) {
    const state = {};
    parentBranches(root).forEach((branch) => {
      const id = branchId(branch);
      if (!id) return;
      state[id] = branch.getAttribute("aria-expanded") === "true";
    });
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }

  function setBranchExpanded(branch, expanded) {
    branch.setAttribute("aria-expanded", expanded ? "true" : "false");
    branch.classList.toggle("is-expanded", expanded);
    const button = branch.querySelector(":scope > .search-within-row .search-within-toggle");
    if (button) button.textContent = expanded ? "▾" : "▸";
  }

  function applyExpandedState(root, state) {
    if (!state) return;

    parentBranches(root).forEach((branch) => {
      const id = branchId(branch);
      if (!id || !Object.prototype.hasOwnProperty.call(state, id)) return;
      if (id.startsWith("file-stats:") && state[id] && branch.dataset.fileStatsChildrenLoaded === "false") return;
      setBranchExpanded(branch, state[id]);
    });
  }

  function syncParent(parentInput, leaves) {
    if (leaves.length === 0) {
      parentInput.checked = false;
      parentInput.indeterminate = false;
      return;
    }
    const checked = leaves.filter((leaf) => leaf.checked).length;
    parentInput.checked = checked === leaves.length;
    parentInput.indeterminate = checked > 0 && checked < leaves.length;
  }

  function syncAllParents(root) {
    parentBranches(root).forEach((branch) => {
      const parentInput = branch.querySelector(":scope > .search-within-row .search-within-parent-input");
      if (!parentInput) return;
      syncParent(parentInput, childLeaves(branch));
    });
  }

  function setLeaves(root, checked) {
    leafInputs(root).forEach((leaf) => {
      leaf.checked = checked;
    });
    syncAllParents(root);
  }

  function scheduleScopeScan() {
    document.dispatchEvent(new CustomEvent("discovery:schedule-scan"));
  }

  function onParentChange(event) {
    const parentInput = event.target;
    const branch = parentInput.closest(".search-within-branch");
    if (!branch) return;
    childLeaves(branch).forEach((leaf) => {
      leaf.checked = parentInput.checked;
    });
    parentInput.indeterminate = false;
    syncAllParents(panel());
    scheduleScopeScan();
  }

  function onLeafChange() {
    syncAllParents(panel());
    scheduleScopeScan();
  }

  function toggleBranch(button) {
    const branch = button.closest(".search-within-branch");
    if (!branch) return;
    const expanded = branch.getAttribute("aria-expanded") === "true";
    setBranchExpanded(branch, !expanded);
    writeExpandedState(panel());
  }

  function compactBookFields(form, root) {
    const books = bookLeaves(root);
    const allBooksChecked = books.length > 0 && books.every((leaf) => leaf.checked);
    if (!allBooksChecked) return;

    books.forEach((leaf) => leaf.removeAttribute("name"));
    let hidden = form.querySelector('input[name="search_selection[all_books]"]');
    if (!hidden) {
      hidden = document.createElement("input");
      hidden.type = "hidden";
      hidden.name = "search_selection[all_books]";
      form.appendChild(hidden);
    }
    hidden.value = "1";
  }

  function init() {
    const root = panel();
    initGenericToggles(document);
    initFileStatsSelection(document);
    if (!root) return;

    applyExpandedState(root, readExpandedState());
    syncAllParents(root);

    root.querySelectorAll(".search-within-parent-input").forEach((input) => {
      input.addEventListener("change", onParentChange);
    });

    leafInputs(root).forEach((input) => {
      input.addEventListener("change", onLeafChange);
    });

    root.querySelectorAll(".search-within-toggle").forEach((button) => {
      button.addEventListener("click", () => toggleBranch(button));
    });

    root.querySelectorAll("[data-search-within-action]").forEach((button) => {
      button.addEventListener("click", () => {
        const action = button.getAttribute("data-search-within-action");
        setLeaves(root, action === "all");
        scheduleScopeScan();
      });
    });

    const form = root.closest("form");
    if (form) {
      form.addEventListener("submit", () => {
        writeExpandedState(root);
        compactBookFields(form, root);
      });
    }
  }

  function initGenericToggles(root) {
    root.querySelectorAll(".search-within-branch .search-within-toggle").forEach((button) => {
      if (button.dataset.genericToggleReady === "true") return;
      button.dataset.genericToggleReady = "true";
      button.addEventListener("click", async () => {
        const branch = button.closest(".search-within-branch");
        if (!branch || branch.closest("#search-within-panel")) return;
        const expanded = branch.getAttribute("aria-expanded") === "true";
        if (!expanded && branch.dataset.branchId?.startsWith("file-stats:")) {
          await loadFileStatsChildren(branch);
        }
        setBranchExpanded(branch, !expanded);
      });
    });
  }

  function initFileStatsSelection(root) {
    const summary = root.getElementById("file-stats-selected-summary");
    if (!summary || summary.dataset.fileStatsSelectionReady === "true") return;

    summary.dataset.fileStatsSelectionReady = "true";
    const title = root.getElementById("file-stats-selected-title");
    const characterTree = root.getElementById("file-stats-character-tree");
    const structureTree = root.getElementById("file-stats-structure-tree");
    const breakdownCache = new Map();
    const fields = {
      letters: summary.querySelector('[data-file-stats-selected="letters"]'),
      digits: summary.querySelector('[data-file-stats-selected="digits"]'),
      other: summary.querySelector('[data-file-stats-selected="other"]'),
      total: summary.querySelector('[data-file-stats-selected="total"]')
    };

    structureTree?.addEventListener("click", (event) => {
      const row = event.target.closest(".file-stats-selectable");
      if (!row || event.target.closest("a, button")) return;

      title.textContent = row.dataset.fileStatsNodeLabel || summary.dataset.defaultLabel || "Selection";
      fields.letters.innerHTML = numberLink(row.dataset.fileStatsLetters);
      fields.digits.innerHTML = numberLink(row.dataset.fileStatsDigits);
      fields.other.innerHTML = numberLink(row.dataset.fileStatsOther);
      fields.total.innerHTML = numberLink(row.dataset.fileStatsTotal);
      bindNumberPreview();
      updateCharacterBreakdown(summary, characterTree, row.dataset.fileStatsNodeId, breakdownCache);
      root.querySelectorAll(".file-stats-selectable.is-selected").forEach((selected) => {
        selected.classList.remove("is-selected");
      });
      row.classList.add("is-selected");
      summary.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  }

  async function loadFileStatsChildren(branch) {
    if (branch.dataset.fileStatsChildrenLoaded === "true") return;

    const tree = branch.closest("#file-stats-structure-tree");
    const list = branch.querySelector(":scope > .search-within-children");
    const nodeId = branch.dataset.fileStatsNodeId;
    if (!tree || !list || !nodeId) return;

    list.innerHTML = `
      <li class="search-within-node">
        <div class="search-within-row file-stats-tree-row file-stats-loading-row">
          <span class="file-stats-spinner" aria-hidden="true"></span>
          <span class="file-stats-node-label">Loading structure</span>
          <span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span>
        </div>
      </li>
    `;

    try {
      const data = await fetchFileStatsChildren(tree.dataset.childrenUrl, nodeId);
      const depth = Number.parseInt(branch.dataset.fileStatsDepth || "0", 10) + 1;
      list.innerHTML = renderFileStatsNodes(data.nodes || [], depth);
      branch.dataset.fileStatsChildrenLoaded = "true";
      initGenericToggles(list);
      bindNumberPreview();
    } catch (_error) {
      list.innerHTML = `
        <li class="search-within-node">
          <div class="search-within-row file-stats-tree-row">
            <span></span>
            <span class="file-stats-node-label">Structure unavailable</span>
            <span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span>
          </div>
        </li>
      `;
    }
  }

  async function fetchFileStatsChildren(baseUrl, nodeId) {
    const url = new URL(baseUrl, window.location.origin);
    url.searchParams.set("node_id", nodeId);
    const response = await fetch(url.toString(), { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error("Structure request failed");

    return response.json();
  }

  function renderFileStatsNodes(nodes, depth) {
    return nodes.map((node) => renderFileStatsNode(node, depth)).join("");
  }

  function renderFileStatsNode(node, depth) {
    const hasChildren = Boolean(node.has_children);
    const totalWordsAndNumbers = node.total_words_and_numbers ?? (
      Number.parseInt(node.word_count || "0", 10) +
      Number.parseInt(node.number_count || "0", 10) +
      Number.parseInt(node.division_count || "0", 10)
    );
    const branchAttrs = hasChildren
      ? ` aria-expanded="false" data-branch-id="file-stats:${escapeHtml(node.node_id)}" data-file-stats-node-id="${escapeHtml(node.node_id)}" data-file-stats-depth="${depth}" data-file-stats-children-loaded="false"`
      : "";
    const toggle = hasChildren
      ? `<button type="button" class="search-within-toggle" aria-label="Toggle ${escapeHtml(node.label)}">▸</button>`
      : '<span class="search-within-toggle" aria-hidden="true"></span>';
    const children = hasChildren ? '<ul class="search-within-children" role="group"></ul>' : "";

    return `
      <li class="search-within-node${hasChildren ? " search-within-branch" : ""}" role="treeitem"${branchAttrs}>
        <div class="search-within-row file-stats-tree-row file-stats-selectable"
             style="--file-stats-depth: ${depth}"
             data-file-stats-node-label="${escapeHtml(node.label)}"
             data-file-stats-node-id="${escapeHtml(node.node_id)}"
             data-file-stats-letters="${escapeHtml(node.letter_count)}"
             data-file-stats-digits="${escapeHtml(node.digit_count)}"
             data-file-stats-other="${escapeHtml(node.other_count)}"
             data-file-stats-total="${escapeHtml(node.character_count)}">
          ${toggle}
          <span class="file-stats-node-label">${escapeHtml(node.label)}</span>
          <span class="file-stats-node-count">${numberLink(node.word_count)}</span>
          <span class="file-stats-node-count">${numberLink(node.number_count)}</span>
          <span class="file-stats-node-count">${numberLink(totalWordsAndNumbers)}</span>
          <span class="file-stats-node-count">${numberLink(node.letter_count)}</span>
          <span class="file-stats-node-count">${numberLink(node.digit_count)}</span>
          <span class="file-stats-node-count">${numberLink(node.other_count)}</span>
          <span class="file-stats-node-count">${numberLink(node.character_count)}</span>
        </div>
        ${children}
      </li>
    `;
  }

  async function updateCharacterBreakdown(summary, tree, nodeId, cache) {
    if (!tree || !nodeId) return;

    tree.setAttribute("aria-busy", "true");
    try {
      const data = cache.has(nodeId) ? cache.get(nodeId) : await beginCharacterBreakdownFetch(summary, tree, nodeId);
      if (!cache.has(nodeId)) cache.set(nodeId, data);
      tree.innerHTML = renderCharacterTree(data);
      initGenericToggles(tree);
      bindNumberPreview();
    } catch (_error) {
      tree.innerHTML = '<li class="search-within-node"><div class="search-within-row file-stats-tree-row"><span></span><span class="file-stats-node-label">Character breakdown unavailable</span><span></span></div></li>';
    } finally {
      tree.removeAttribute("aria-busy");
    }
  }

  async function beginCharacterBreakdownFetch(summary, tree, nodeId) {
    tree.innerHTML = `
      <li class="search-within-node">
        <div class="search-within-row file-stats-tree-row file-stats-loading-row">
          <span class="file-stats-spinner" aria-hidden="true"></span>
          <span class="file-stats-node-label">Loading character counts</span>
          <span></span>
        </div>
      </li>
    `;
    return fetchCharacterBreakdown(summary.dataset.breakdownUrl, nodeId);
  }

  async function fetchCharacterBreakdown(baseUrl, nodeId) {
    const url = new URL(baseUrl, window.location.origin);
    url.searchParams.set("node_id", nodeId);
    const response = await fetch(url.toString(), { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error("Character breakdown request failed");

    return response.json();
  }

  function renderCharacterTree(data) {
    const categories = groupBy(data.categories || [], "category");
    const characters = groupBy(data.characters || [], "category");
    return Object.keys(categories).sort().map((category) => {
      const rows = categories[category];
      const total = (rows.find((row) => row.subcategory === "total") || { count: sumCounts(rows) }).count;
      const charRows = characters[category] || [];
      const subtotalRows = rows
        .filter((row) => row.subcategory && row.subcategory !== "total")
        .filter((row) => category !== "whitespace" || !charRows.some((char) => whitespaceSubcategoryForCharacter(char.char) === row.subcategory))
        .sort((a, b) => subcategorySortKey(a.subcategory).localeCompare(subcategorySortKey(b.subcategory)));
      const subtotalChildren = subtotalRows.map((row) => `
        <li class="search-within-node" role="treeitem">
          <div class="search-within-row file-stats-tree-row">
            <span class="search-within-toggle" aria-hidden="true"></span>
            <span class="file-stats-node-label">${escapeHtml(categoryLabel(row.subcategory))}</span>
            <span class="file-stats-node-count">${numberLink(row.count)}</span>
          </div>
        </li>
      `).join("");
      const children = charRows.map((char) => `
        <li class="search-within-node" role="treeitem">
          <div class="search-within-row file-stats-tree-row">
            <span class="search-within-toggle" aria-hidden="true"></span>
            <span class="file-stats-node-label file-stats-character-label">
              <span class="file-stats-character-symbol">${escapeHtml(characterSymbol(char.char))}</span>
              <span>${escapeHtml(char.name)}</span>
            </span>
            <span class="file-stats-node-count">${numberLink(char.count)}</span>
          </div>
        </li>
      `).join("");

      return `
        <li class="search-within-node search-within-branch" role="treeitem" aria-expanded="false"
            data-branch-id="file-stats-character:${escapeHtml(category)}">
          <div class="search-within-row file-stats-tree-row">
            <button type="button" class="search-within-toggle" aria-label="Toggle ${escapeHtml(category)}">▸</button>
            <span class="file-stats-node-label">${escapeHtml(categoryLabel(category))}</span>
            <span class="file-stats-node-count">${numberLink(total)}</span>
          </div>
          <ul class="search-within-children" role="group">${subtotalChildren}${children}</ul>
        </li>
      `;
    }).join("");
  }

  function subcategorySortKey(value) {
    const order = {
      uppercase: "01",
      lowercase: "02",
      small_caps: "03",
      vowels: "04",
      consonants: "05",
      other_letters: "06",
      space: "01",
      newline: "02",
      tab: "03",
      carriage_return: "04",
      other_whitespace: "05"
    };
    return `${order[value] || "99"}:${value}`;
  }

  function groupBy(rows, key) {
    return rows.reduce((groups, row) => {
      const value = row[key];
      groups[value] ||= [];
      groups[value].push(row);
      return groups;
    }, {});
  }

  function sumCounts(rows) {
    return rows.reduce((sum, row) => sum + Number.parseInt(row.count || "0", 10), 0);
  }

  function categoryLabel(value) {
    return {
      letters: "Letters",
      digits: "Digits",
      punctuation: "Punctuation",
      whitespace: "Whitespace",
      other: "Other characters",
      uppercase: "Uppercase",
      lowercase: "Lowercase",
      small_caps: "Small caps",
      vowels: "Vowels",
      consonants: "Consonants",
      other_letters: "Other letters",
      space: "Space",
      newline: "Newline",
      tab: "Tab",
      carriage_return: "Carriage return",
      other_whitespace: "Other whitespace"
    }[value] || String(value).replaceAll("_", " ");
  }

  function numberLink(value) {
    const number = Number.parseInt(value || "0", 10);
    const formatted = formatNumber(value);
    if (Number.isNaN(number) || number <= 0) return formatted;

    const classes = number % 7 === 0 ? "number-link number-link-seven" : "number-link";
    return `<a class="${classes}" href="/numbers/${number}" data-number-preview-url="/numbers/${number}/preview">${formatted}</a>`;
  }

  function bindNumberPreview() {
    window.InamenNumberPreview?.bind?.();
  }

  function characterSymbol(value) {
    switch (value) {
      case " ":
        return "Space";
      case "\n":
        return "Newline";
      case "\t":
        return "Tab";
      case "\r":
        return "CR";
      default:
        return value;
    }
  }

  function whitespaceSubcategoryForCharacter(value) {
    switch (value) {
      case " ":
        return "space";
      case "\n":
        return "newline";
      case "\t":
        return "tab";
      case "\r":
        return "carriage_return";
      default:
        return null;
    }
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function formatNumber(value) {
    const number = Number.parseInt(value || "0", 10);
    return new Intl.NumberFormat().format(Number.isNaN(number) ? 0 : number);
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
