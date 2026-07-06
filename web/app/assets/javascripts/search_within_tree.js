(function () {
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

  function onParentChange(event) {
    const parentInput = event.target;
    const branch = parentInput.closest(".search-within-branch");
    if (!branch) return;
    childLeaves(branch).forEach((leaf) => {
      leaf.checked = parentInput.checked;
    });
    parentInput.indeterminate = false;
    syncAllParents(panel());
  }

  function onLeafChange() {
    syncAllParents(panel());
  }

  function toggleBranch(button) {
    const branch = button.closest(".search-within-branch");
    if (!branch) return;
    const expanded = branch.getAttribute("aria-expanded") === "true";
    branch.setAttribute("aria-expanded", expanded ? "false" : "true");
    branch.classList.toggle("is-expanded", !expanded);
    button.textContent = expanded ? "▸" : "▾";
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
      });
    });

    const form = root.closest("form");
    if (form) {
      form.addEventListener("submit", () => compactBookFields(form, root));
    }
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
