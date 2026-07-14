(function () {
  const DICTIONARY_CACHE_KEY = "inamen:discover-dictionary";
  const MAX_SUGGESTIONS = 12;
  const WILDCARD_FRAGMENT = "(?:[\\p{L}\\p{M}0-9\\-]*)";

  let dictionary = null;
  let dictionaryPromise = null;
  let dictionaryPromiseUrl = null;
  let dictionaryLoadedUrl = null;
  let normWords = null;

  function panel() {
    return document.getElementById("search-phrases-panel");
  }

  function dictionaryUrl() {
    const root = panel();
    return root ? root.dataset.dictionaryUrl : null;
  }

  function dictionaryCacheKey(url) {
    return `${DICTIONARY_CACHE_KEY}:${url}`;
  }

  function normalizeApostrophe(text) {
    return text.replace(/'/g, "\u2019");
  }

  function normalizeToken(text) {
    return normalizeApostrophe(text.toLowerCase()).replace(/æ/g, "ae").replace(/œ/g, "oe");
  }

  function wildcardPattern(pattern) {
    return pattern.includes("*");
  }

  function buildNormWords(words) {
    const index = new Map();
    words.forEach((word) => {
      if (wildcardPattern(word)) return;
      const norm = normalizeToken(word);
      if (!index.has(norm)) index.set(norm, []);
      const list = index.get(norm);
      if (!list.includes(word)) list.push(word);
    });
    index.forEach((list) => list.sort());
    return index;
  }

  function loadDictionary() {
    const url = dictionaryUrl();
    if (!url) return Promise.resolve([]);

    if (dictionary && dictionaryLoadedUrl === url) return Promise.resolve(dictionary);
    if (dictionaryPromise && dictionaryPromiseUrl === url) return dictionaryPromise;

    dictionary = null;
    normWords = null;
    dictionaryLoadedUrl = null;

    const cacheKey = dictionaryCacheKey(url);
    const cached = sessionStorage.getItem(cacheKey);
    if (cached) {
      try {
        dictionary = JSON.parse(cached);
        normWords = buildNormWords(dictionary);
        dictionaryLoadedUrl = url;
        return Promise.resolve(dictionary);
      } catch (_error) {
        sessionStorage.removeItem(cacheKey);
      }
    }

    dictionaryPromiseUrl = url;
    dictionaryPromise = fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((payload) => {
        const words = payload.words || [];
        if (dictionaryUrl() !== url) return words;

        dictionary = words;
        normWords = buildNormWords(words);
        dictionaryLoadedUrl = url;
        try {
          sessionStorage.setItem(cacheKey, JSON.stringify(words));
        } catch (_error) {
          /* ignore quota errors */
        }
        return words;
      })
      .catch(() => {
        if (dictionaryUrl() !== url) return [];

        dictionary = [];
        normWords = new Map();
        dictionaryLoadedUrl = url;
        return dictionary;
      })
      .finally(() => {
        dictionaryPromise = null;
        dictionaryPromiseUrl = null;
      });

    return dictionaryPromise;
  }

  function splitInput(text, caseSensitive) {
    if (!text) return { complete: [], partial: null };
    if (/\s$/.test(text)) {
      return { complete: text.trim().split(/\s+/).filter(Boolean), partial: null };
    }
    const parts = text.split(/\s+/);
    if (parts.length === 1) {
      const token = parts[0];
      if (validCompleteToken(token, caseSensitive)) return { complete: [token], partial: null };
      return { complete: [], partial: token };
    }
    const last = parts[parts.length - 1];
    const complete = parts.slice(0, -1);
    if (validCompleteToken(last, caseSensitive)) return { complete: complete.concat(last), partial: null };
    return { complete, partial: last };
  }

  function wildcardRegex(pattern, caseSensitive) {
    const parts = normalizeApostrophe(pattern).split("*");
    const source = parts.map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(WILDCARD_FRAGMENT);
    const flags = caseSensitive ? "u" : "ui";
    return new RegExp(`^${source}$`, flags);
  }

  function prefixMatches(words, prefix, limit) {
    const matches = [];
    for (let i = 0; i < words.length && matches.length < limit; i += 1) {
      if (words[i].startsWith(prefix)) matches.push(words[i]);
    }
    return matches;
  }

  function prefixSuggestions(prefix, caseSensitive) {
    if (!prefix) return [];
    if (caseSensitive) return prefixMatches(dictionary, prefix, MAX_SUGGESTIONS);

    const normPrefix = normalizeToken(prefix);
    const matches = [];
    for (const [norm, words] of normWords.entries()) {
      if (!norm.startsWith(normPrefix)) continue;
      words.forEach((word) => {
        if (matches.length < MAX_SUGGESTIONS && !matches.includes(word)) matches.push(word);
      });
      if (matches.length >= MAX_SUGGESTIONS) break;
    }
    return matches.sort().slice(0, MAX_SUGGESTIONS);
  }

  function wildcardSuggestions(pattern, caseSensitive) {
    const regex = wildcardRegex(pattern, caseSensitive);
    const matches = [];
    for (let i = 0; i < dictionary.length && matches.length < MAX_SUGGESTIONS; i += 1) {
      const word = dictionary[i];
      if (regex.test(word)) matches.push(word);
    }
    return matches;
  }

  function validCompleteToken(token, caseSensitive) {
    if (!token) return false;
    if (wildcardPattern(token)) return wildcardSuggestions(token, caseSensitive).length > 0;
    if (caseSensitive) return dictionary.includes(normalizeApostrophe(token));
    return normWords.has(normalizeToken(token));
  }

  function validPartialToken(token, caseSensitive) {
    if (!token) return false;
    if (wildcardPattern(token)) return wildcardSuggestions(token, caseSensitive).length > 0;
    if (caseSensitive) return prefixMatches(dictionary, token, 1).length > 0;
    const normPrefix = normalizeToken(token);
    for (const norm of normWords.keys()) {
      if (norm.startsWith(normPrefix)) return true;
    }
    return false;
  }

  function analyzeBranch(text, caseSensitive) {
    const tokens = splitInput(text, caseSensitive);
    const preview = tokens.complete.map((token) => ({
      text: token,
      valid: validCompleteToken(token, caseSensitive)
    }));
    if (tokens.partial) {
      const partialValid = wildcardPattern(tokens.partial)
        ? validPartialToken(tokens.partial, caseSensitive)
        : false;
      preview.push({
        text: tokens.partial,
        valid: partialValid
      });
    }

    const suggestions = tokens.partial
      ? wildcardPattern(tokens.partial)
        ? wildcardSuggestions(tokens.partial, caseSensitive)
        : prefixSuggestions(tokens.partial, caseSensitive)
      : [];

    const canSearch =
      tokens.partial === null &&
      tokens.complete.length > 0 &&
      tokens.complete.every((token) => validCompleteToken(token, caseSensitive));

    return { preview, suggestions, canSearch };
  }

  function analyzePhrase(phrase, caseSensitive) {
    const branches = phrase
      .split("|")
      .map((part) => part.trim())
      .filter(Boolean)
      .map((branch) => analyzeBranch(branch, caseSensitive));

    if (branches.length === 0) {
      return { branches: [], canSearch: false, suggestions: [] };
    }

    const active = branches.reduce((best, branch) =>
      branch.preview.length > best.preview.length ? branch : best
    );

    return {
      branches,
      canSearch: branches.some((branch) => branch.canSearch),
      suggestions: active.suggestions
    };
  }

  function escapeHtml(text) {
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function renderPreview(analysis) {
    return analysis.branches
      .map((branch) =>
        branch.preview
          .map((segment) =>
            segment.valid
              ? `<span class="search-phrase-preview-token">${escapeHtml(segment.text)}</span>`
              : `<span class="search-phrase-preview-token is-invalid">${escapeHtml(segment.text)}</span>`
          )
          .join('<span class="search-phrase-preview-space"> </span>')
      )
      .join('<span class="search-phrase-preview-pipe"> | </span>');
  }

  function rowCaseSensitive(row) {
    const checkbox = row.querySelector('input[name$="[case_sensitive]"]');
    return checkbox ? checkbox.checked : false;
  }

  function rowDisabled(row) {
    const checkbox = row.querySelector("[data-search-phrase-disable]");
    return checkbox ? checkbox.checked : false;
  }

  function rowExcluded(row) {
    const checkbox = row.querySelector('input[name$="[exclude]"]');
    return checkbox ? checkbox.checked : false;
  }

  function updateRow(row, options = {}) {
    const userInitiated = options.userInitiated === true;
    const input = row.querySelector(".search-phrase-input");
    const preview = row.querySelector("[data-phrase-preview]");
    const suggestions = row.querySelector("[data-phrase-suggestions]");
    if (!input || !preview || !suggestions) return;

    if (rowDisabled(row) || !dictionary) {
      preview.innerHTML = "";
      preview.hidden = true;
      suggestions.hidden = true;
      row.dataset.canSearch = "false";
      return;
    }

    if (rowExcluded(row)) {
      preview.innerHTML = "";
      preview.hidden = true;
      suggestions.hidden = true;
      row.dataset.canSearch = "false";
      document.dispatchEvent(new CustomEvent("discovery:phrase-validity-changed"));
      return;
    }

    const phrase = input.value;
    if (!phrase.trim()) {
      preview.innerHTML = "";
      preview.hidden = true;
      suggestions.hidden = true;
      row.dataset.canSearch = "false";
      document.dispatchEvent(new CustomEvent("discovery:phrase-validity-changed"));
      return;
    }

    const wasCanSearch = row.dataset.canSearch === "true";
    const analysis = analyzePhrase(phrase, rowCaseSensitive(row));
    preview.innerHTML = renderPreview(analysis);
    preview.hidden = false;
    row.dataset.canSearch = analysis.canSearch ? "true" : "false";

    suggestions.innerHTML = "";
    if (analysis.suggestions.length > 0) {
      analysis.suggestions.forEach((word) => {
        const item = document.createElement("li");
        const button = document.createElement("button");
        button.type = "button";
        button.className = "search-phrase-suggestion";
        button.textContent = word;
        button.addEventListener("mousedown", (event) => event.preventDefault());
        button.addEventListener("click", () => {
          applySuggestion(input, word);
          updateRow(row);
          document.dispatchEvent(new CustomEvent("discovery:phrase-validity-changed"));
          if (row.dataset.canSearch === "true") {
            document.dispatchEvent(
              new CustomEvent("discovery:schedule-scan", { detail: { rememberFocus: true, trigger: input } })
            );
          }
        });
        item.appendChild(button);
        suggestions.appendChild(item);
      });
      suggestions.hidden = false;
    } else {
      suggestions.hidden = true;
    }

    document.dispatchEvent(new CustomEvent("discovery:phrase-validity-changed"));

    if (userInitiated && analysis.canSearch && !wasCanSearch) {
      document.dispatchEvent(
        new CustomEvent("discovery:schedule-scan", { detail: { rememberFocus: true, trigger: input } })
      );
    }
  }

  function applySuggestion(input, word) {
    const value = input.value;
    const caseSensitive = rowCaseSensitive(input.closest("[data-search-phrase-row]"));
    const tokens = splitInput(value, caseSensitive);
    if (tokens.partial === null) {
      input.value = value.trim() ? `${value.trim()} ${word}` : word;
      return;
    }

    const completePrefix = tokens.complete.length > 0 ? `${tokens.complete.join(" ")} ` : "";
    input.value = `${completePrefix}${word}`;
  }

  function updateAllRows(root) {
    root.querySelectorAll("[data-search-phrase-row]").forEach((row) => updateRow(row));
  }

  function bindRow(row) {
    const input = row.querySelector(".search-phrase-input");
    if (!input) return;

    input.addEventListener("input", () => updateRow(row, { userInitiated: true }));
    input.addEventListener("focus", () => updateRow(row));
    row.querySelectorAll('input[type="checkbox"]').forEach((checkbox) => {
      checkbox.addEventListener("change", () => updateRow(row));
    });
  }

  function init() {
    const root = panel();
    if (!root) return;

    loadDictionary().then(() => {
      root.querySelectorAll("[data-search-phrase-row]").forEach((row) => {
        bindRow(row);
        updateRow(row);
      });
      document.dispatchEvent(new CustomEvent("discovery:phrases-ready"));
    });

    document.addEventListener("discovery:search-phrase-row-added", (event) => {
      const row = event.detail?.row;
      if (!row || !root.contains(row)) return;
      bindRow(row);
      updateRow(row);
    });
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
