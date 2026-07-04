# Inamen — Biblical text feature verification

## Purpose

**Inamen** verifies a plain-text Bible file against a catalog of **documented numeric and structural features** — patterns whose definitions are explicit, reproducible, and testable. The reference corpus today is the bundled King James Version (`data/KJV.txt`), aligned where possible with [KJV Code](https://kjvcode.com) / King James Pure Bible Search (KJPBS).

The **ultimate goal** is a general verification engine: point it at *any* Bible text file and report which known features match, which miss, and what else might be worth studying. That includes other English editions (NKJV, WEB, etc.) and, eventually, foreign-language texts — multilingual support is **not implemented yet**, but the architecture should stay parser- and feature-driven so new languages can plug in behind the same verification API.

A second long-term goal is **discovery**: surfacing candidate patterns the catalog does not yet describe (for example token counts divisible by seven, boundary-word co-occurrences, or verse-level symmetries). Today the CLI includes a divisibility scan as an early step toward that; a full discovery pipeline is planned.

## Roadmap: web application

The plan is a **Rails** application that wraps this library:

- **Registered, paid users** upload a Bible text file.
- The site runs the full **feature verification** suite and presents pass/fail results with diffs against expected counts.
- Users can run **discovery scans** on their upload to hunt for new numeric or structural patterns.
- Results are stored per upload so users can compare revisions, translations, or editions over time.

### Suggested site functionality (beyond core verify + discover)

| Area | Ideas |
|------|--------|
| **Comparison** | Side-by-side two uploads (e.g. Cambridge KJV vs user file); highlight verses or tokens that change feature counts. |
| **Reference alignment** | Optional alignment to KJPBS / kjvcode.com expected values; export a reconciliation report. |
| **Feature browser** | Searchable catalog with definitions, formulas, example verses, and links to source code. |
| **Custom feature sets** | Curated bundles (“7⁷ basics”, “Alpha & Omega”, “N.T. concealed capitals”) for focused audits. |
| **Chapter & book drill-down** | Per-chapter totals, chapters divisible by 7, boundary-token heatmaps. |
| **Upload validation** | Pre-flight parser report: malformed lines, missing books, canon mismatches, encoding issues. |
| **API access** | JSON API for programmatic verification (CI for text publishers, Bible software teams). |
| **Community patterns** | Submit a proposed feature; moderators promote vetted patterns into the global catalog. |
| **Notifications** | Alert when a re-upload fixes or breaks a previously failing feature. |
| **Export** | PDF/CSV verification certificate, shareable read-only link for a completed audit. |
| **Admin** | Corpus management, feature versioning, usage metering for paid tiers. |

This repository is the **core engine** (parser, indexer, feature catalog, CLI). The Rails app will depend on it as a gem or mounted service.

---

## What works today

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

New features should include:

1. A clear **definition** (tokens, scope, case rules, exclusions).
2. An **expected count** on `data/KJV.txt` (and `kjvcode_expected_count` when applicable).
3. **RSpec** coverage so regressions are caught.

Discovery candidates can start as scan results or alignment diffs before promotion into `Features::CATALOG`.
