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

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
