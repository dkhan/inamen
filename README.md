# Inamen — Text pattern verification

## Purpose

**Inamen** analyzes plain-text documents for **documented numeric and structural patterns** — features whose definitions are explicit, reproducible, and testable. It reports which patterns match, which miss, and (eventually) what else in the text might be worth studying.

**Today** the engine is built around the Christian Bible: the bundled King James Version (`data/KJV.txt`) is the reference corpus, with eighteen catalogued features aligned where possible to [KJV Code](https://kjvcode.com) / King James Pure Bible Search (KJPBS).

**Long term**, the same engine should work on **any text, in any tradition** — not only Bibles. Examples:

- Other English or foreign-language scripture (Quran, Bhagavad Gita, Torah editions, etc.)
- Ancient Greek poetry, classical corpora, or other literary works
- Any UTF-8 plain text a user uploads, with patterns defined for that corpus

That requires **pluggable parsers** (how lines, stanzas, surahs, or chapters are recognized), **pluggable tokenizers** (script and language rules), and **corpus-specific feature catalogs** (what “correct” looks like for a given work). None of that generalization is implemented yet; the current code is Bible/KJV-specific. The architecture should stay feature-driven so new corpora can plug in behind the same verify-and-discover API.

A parallel goal is **discovery**: surfacing candidate patterns the catalog does not yet describe — divisibility, boundary-word co-occurrence, positional symmetries, repeated n-grams, and so on. The CLI’s divisibility scan is an early step; a fuller discovery pipeline is planned.

## Roadmap: web application

The plan is a **Rails** application that wraps this library:

- **Registered users** (and **super users** for advanced tooling) upload a plain-text file.
- The user selects a **corpus profile** (e.g. KJV Bible, another Bible edition, or — later — Quran, Bhagavad Gita, Greek poetry, custom).
- The site runs **verification** against that profile’s feature catalog and shows pass/fail results with diffs.
- Users can run **discovery scans** on any upload to hunt for new numeric or structural patterns, regardless of domain.
- Results are stored per upload so users can compare revisions, translations, or editions over time.

### Suggested site functionality (beyond core verify + discover)

| Area | Ideas |
|------|--------|
| **Corpus profiles** | Per-tradition parsers and feature sets (Bible, Quran, Vedas, classical Greek, user-defined). |
| **Comparison** | Side-by-side two uploads; highlight lines or tokens that change pattern counts. |
| **Reference alignment** | Optional alignment to published reference counts (e.g. KJPBS / kjvcode.com for KJV). |
| **Feature browser** | Searchable catalog with definitions, formulas, example locations, and source links. |
| **Custom feature sets** | Curated bundles per corpus (“7⁷ basics”, “Alpha & Omega”, surah-level totals, meter patterns). |
| **Structure drill-down** | Per-chapter, per-surah, or per-stanza totals; heatmaps for boundary or keyword tokens. |
| **Upload validation** | Pre-flight report: encoding, structure, missing sections, canon or schema mismatches. |
| **API access** | JSON API for programmatic verification (publishers, scholars, software integrations). |
| **Community patterns** | Submit a proposed feature; moderators promote vetted patterns into a corpus catalog. |
| **Notifications** | Alert when a re-upload fixes or breaks a previously failing feature. |
| **Export** | PDF/CSV verification report, shareable read-only link for a completed audit. |
| **Admin** | Corpus management, feature versioning, usage limits for registered and super-user accounts. |

This repository is the **core engine** (parser, indexer, feature catalog, CLI). The Rails app will depend on it as a gem or mounted service.

---

## What works today (KJV / Bible)

The following is **implemented for the KJV plain-text layout only**. General text or other sacred works are not yet supported.

### Parsing & tokenization

- Deterministic line-by-line parser for the KJV plain-text layout ([`KjvLineParser`](lib/inamen/kjv_line_parser.rb), [`CountingService`](lib/inamen/counting_service.rb)).
- Unicode word tokenization with hyphens and both apostrophe forms ([`Tokenizer`](lib/inamen/tokenizer.rb)).
- Psalm-aware logic: titles, superscriptions, implicit verse 1, Psalm 119 stanza labels, split verse lines.
- Bucketed counts (verse text, headings, colophons, chapter/verse numbers) that sum to **823,543 = 7⁷** on the reference file.

### Indexed corpus

- [`bin/inamen index`](bin/inamen) builds `data/kjv_corpus.sqlite` (~790k scannable tokens) for fast SQL-backed queries.
- [`bin/inamen scan`](bin/inamen) finds tokens whose counts are divisible by a chosen integer (default 7).

### Feature catalog

Eighteen named features in [`Features::CATALOG`](lib/inamen/features.rb), including:

- Combined total **7⁷**
- Peter / Paul **153** verses; John 21 fishing party **153** (Gospels)
- Jesus mentions **980**; Bible boundary words **77,777**
- KJV Code patterns: The\* + Amen N.T. **980**, God\* pure N.T. **1370**, Jesus + boundary same verse **2,401**, first 7 N.T. books **539**
- And more (see CLI below)

[`bin/inamen kjvcode-align`](bin/inamen) compares corpus counts to kjvcode.com targets.

### Tests

Full-file RSpec suite on `data/KJV.txt` locks parser totals and feature expected counts. Shared test fixture builds the corpus once per run (~4 minutes).

---

## Installation

1. **Ruby** 3.1+ (3.2 or 3.3 recommended).

2. **Dependencies**

   ```bash
   bundle install
   ```

3. **Data** — `data/KJV.txt` is the default input.

4. **Optional index** (speeds up `feature` and `scan` commands)

   ```bash
   bin/inamen index
   ```

---

## CLI usage

### Summary & features

```bash
bin/inamen                          # Public KJV summary + 7⁷ total
bin/inamen features                 # Table of all catalog features
bin/inamen feature combined_total   # Run one feature
bin/inamen feature --all            # Run every feature; report match/miss
bin/inamen kjvcode-align            # KJV Code alignment report
```

### Corpus & discovery

```bash
bin/inamen index [--force]          # Build SQLite corpus
bin/inamen scan                     # Tokens with counts divisible by 7
bin/inamen scan -s nt -m 14         # N.T. only, min count 14
```

### Chapter tools

```bash
bin/inamen chapter Genesis 1
bin/inamen chapters-divisible-by-7
```

### Parser debug

| Command | Purpose |
|---------|---------|
| `bin/inamen book-stats-debug` | Per-book chapter/verse counts vs canon (`--all` for every book) |
| `bin/inamen text-words-debug` | Lines contributing to non-verse `text_words` |
| `bin/inamen psalm-heading-words-debug` | Psalm superscription lines |
| `bin/inamen psalms-unclassified-debug` | Unclassified text in Psalms |
| `bin/inamen numeric-chapters-debug` | Digit-only chapter marker lines |
| `bin/inamen line-samples [N]` | Sample lines per classifier category |
| `bin/inamen psalm-debug` | Each `PSALM n` line with following context |

### Tests

```bash
bundle exec rspec
```

---

## Project layout

| Path | Role |
|------|------|
| `lib/inamen/` | Parser, tokenizer, verse index, feature definitions |
| `lib/inamen/features.rb` | Feature catalog and runners |
| `lib/inamen/bible_boundary_patterns.rb` | Alpha/Omega & KJV Code boundary logic |
| `lib/inamen/corpus_store.rb` | SQLite token index |
| `data/KJV.txt` | Reference plain-text KJV |
| `bin/inamen` | CLI entry point |
| `spec/` | RSpec; `spec/support/kjv_fixture.rb` shared corpus |

---

## Contributing

New **Bible/KJV** features should include:

1. A clear **definition** (tokens, scope, case rules, exclusions).
2. An **expected count** on `data/KJV.txt` (and `kjvcode_expected_count` when applicable).
3. **RSpec** coverage so regressions are caught.

Discovery candidates can start as scan results or alignment diffs before promotion into `Features::CATALOG`.

For **non-Biblical corpora**, contributions should eventually include a parser profile, tokenizer rules, and a feature catalog appropriate to that text — the same verify-and-discover workflow, different schema.
