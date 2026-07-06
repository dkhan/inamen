# Inamen — Text pattern verification

## Purpose

**Inamen** analyzes plain-text documents for **documented numeric and structural patterns** — features whose definitions are explicit, reproducible, and testable. It reports which patterns match, which miss, and what else in the text might be worth studying.

**Today** the engine is built around the Christian Bible. The reference corpus is `data/KJV.txt` (`kjv_normalized`), with a second bundled edition (`concord`, Cambridge Concord layout). Eighteen catalogued features align where possible with [KJV Code](https://kjvcode.com) / King James Pure Bible Search (KJPBS).

**Long term**, the same engine should work on **any text, in any tradition** — not only Bibles. That requires pluggable parsers, tokenizers, and corpus-specific feature catalogs. The current code is Bible/KJV-specific; the architecture is feature-driven so new corpora can plug in behind the same verify-and-discover API.

---

## What works today

### Core engine (`lib/inamen/`)

| Area | Details |
|------|---------|
| **Parser** | Deterministic KJV-shaped line parser ([`KjvLineParser`](lib/inamen/kjv_line_parser.rb)); Psalm titles, colophons, implicit verse 1, split verses |
| **Tokenization** | Unicode words; hyphens; straight and curly apostrophes ([`Tokenizer`](lib/inamen/tokenizer.rb)) |
| **7⁷ total** | Bucketed counts sum to **823,543 = 7⁷** on the reference file |
| **Feature catalog** | 18 named features ([`Features::CATALOG`](lib/inamen/features.rb)): boundary words, Jesus/Peter/Paul patterns, KJV Code alignments, file totals, and more |
| **Editions** | `kjv_normalized` (`KJV.txt`), `concord` (Concord text + normalization for chapter-opening capitalization) |
| **Corpus index** | SQLite `tokens` table (~790k scannable rows) plus materialized `token_counts` for fast discovery |
| **Lexicon** | In-memory count cache per Search Within selection ([`Lexicon`](lib/inamen/lexicon.rb)); sub-100ms word-count scans on a warm corpus |
| **CLI** | [`bin/inamen`](bin/inamen) — summary, features, indexing, divisibility scan, debug tools |

### Web application (`web/`)

Rails 8 app mounted on the gem. See **[web/README.md](web/README.md)** for setup and production deployment.

| Route | Function |
|-------|----------|
| `/` | Home — engine version, edition list, checksums |
| `/features` | Feature catalog — live counts vs expected, edition switcher, KJV Code alignment |
| `/features/:id` | Single feature definition and detail lines |
| `/discover` | Pattern discovery with KJPBS-style **Search Within** tree (colophons, superscriptions, OT/NT book groups) |

**Discovery scan types:**

- **Word count** — exact and `*` wildcard terms (`*jesus*`, `six|cs` for case-sensitive)
- **Divisible by N** — tokens whose counts divide evenly
- **Equal occurrence count** — groups of words sharing the same count (normalized or per-spelling)

Edition selection persists across Features and Discover. Scan and verification results cache for one week.

---

## Installation (engine + CLI)

1. **Ruby** 3.2+ (see `.ruby-version` in `web/`).

2. **Dependencies**

   ```bash
   bundle install
   ```

3. **Data** — bundled under `data/`:
   - `KJV.txt` — reference normalized KJV
   - `Holy-Bible-King-James-Version-Entire-Bible-Concord.txt` — Concord edition

4. **Corpus index** (recommended for CLI `scan` / fast feature runs)

   ```bash
   # All bundled editions → data/corpora/{edition}-{checksum}-{revision}.sqlite
   bin/inamen corpora prebuild

   # Legacy single-file index for KJV.txt only
   bin/inamen index
   ```

   Prebuilt files are gitignored (~130 MB each). Rebuild after indexer changes (`CorpusStore::INDEXER_REVISION`) or with `--force`.

---

## CLI usage

### Summary & features

```bash
bin/inamen                          # KJV summary + 7⁷ total
bin/inamen features                 # Table of all catalog features
bin/inamen feature combined_total   # Run one feature
bin/inamen feature --all            # Run every feature; report match/miss
bin/inamen kjvcode-align            # KJV Code alignment report
```

### Corpus & discovery

```bash
bin/inamen corpora prebuild [--force]   # Build all edition corpora (preferred)
bin/inamen index [--force]              # Legacy: data/kjv_corpus.sqlite
bin/inamen scan                         # Tokens with counts divisible by 7
bin/inamen scan -s nt -m 14             # N.T. only, min count 14
```

### Chapter & parser debug

```bash
bin/inamen chapter Genesis 1
bin/inamen chapters-divisible-by-7
bin/inamen book-stats-debug
bin/inamen line-samples 5
```

Run `bin/inamen` with no arguments for the full command list.

### Tests

```bash
bundle exec rspec
```

The suite uses a shared KJV corpus fixture (`spec/support/kjv_fixture.rb`). A full run takes several minutes on first build.

---

## Production deployment

The web app lives in **`web/`** and loads the engine as a path gem (`gem "inamen", path: ".." `).

### Quick checklist

1. Clone the repo (monorepo — engine and web ship together).
2. Install Ruby 3.2+ and Bundler.
3. From `web/`:

   ```bash
   bundle install
   bin/rails db:prepare
   bin/rails inamen:corpora:prebuild
   ```

4. Boot Puma (or your app server):

   ```bash
   RAILS_ENV=production bin/rails assets:precompile
   RAILS_ENV=production bundle exec puma -C config/puma.rb
   ```

5. Optional: run Solid Queue inside Puma for background corpus/verification jobs on first deploy without prebuilt corpora:

   ```bash
   export SOLID_QUEUE_IN_PUMA=1
   ```

### Why prebuild matters

Without prebuilt corpora, the first Features verification or Discover scan **builds a SQLite index from plain text** (~1 minute per edition). Prebuilding at deploy time puts ready-made indexes in `data/corpora/` so the app opens them immediately.

Corpus filenames include the text checksum and indexer revision, e.g.:

```
data/corpora/kjv_normalized-73f86fc083e56c48-7.sqlite
data/corpora/concord-a67031a2ae4db3bc-7.sqlite
```

Runtime copies are only created in `web/tmp/corpora/` when no prebuilt file exists.

### Environment variables

| Variable | Purpose |
|----------|---------|
| `RAILS_ENV` | `production` for deploy |
| `RAILS_MASTER_KEY` | Decrypt credentials (`config/master.key` is not in git) |
| `PORT` | HTTP port (default 3000) |
| `RAILS_MAX_THREADS` | Puma thread count |
| `WEB_CONCURRENCY` | Puma workers (optional) |
| `SOLID_QUEUE_IN_PUMA` | Run job workers in the Puma process (single-server deploys) |
| `RAILS_LOG_LEVEL` | Log verbosity (default `info`) |
| `FORCE=1` | Pass to `inamen:corpora:prebuild` to rebuild existing corpora |

### Health check

Rails exposes `GET /up` for load balancers and uptime monitors.

Full web setup, development workflow, and deploy notes: **[web/README.md](web/README.md)**.

---

## Project layout

| Path | Role |
|------|------|
| `lib/inamen/` | Engine — parser, tokenizer, features, discovery scans |
| `lib/inamen/corpus_store.rb` | SQLite schema, `tokens` + `token_counts` tables |
| `lib/inamen/corpus_publisher.rb` | Prebuilt corpus paths and `corpora prebuild` |
| `lib/inamen/lexicon.rb` | In-memory discovery count index |
| `lib/inamen/kjv_editions.rb` | Bundled edition registry and Concord normalization |
| `lib/inamen/search_selection.rb` | KJPBS-style Search Within scope |
| `data/KJV.txt` | Reference normalized KJV |
| `data/corpora/` | Prebuilt SQLite indexes (generated; gitignored) |
| `bin/inamen` | CLI entry point |
| `web/` | Rails 8 application |
| `spec/` | RSpec; shared `KjvFixture` corpus |

---

## Roadmap (not yet implemented)

- User uploads and corpus profiles beyond bundled KJV editions
- Registered users, saved results, edition comparison UI
- JSON API for programmatic verification

---

## Contributing

New **Bible/KJV** features should include:

1. A clear **definition** (tokens, scope, case rules, exclusions).
2. An **expected count** on `data/KJV.txt` (and `kjvcode_expected_count` when applicable).
3. **RSpec** coverage so regressions are caught.

Bump `CorpusStore::INDEXER_REVISION` when tokenization or indexing rules change, and rebuild corpora (`bin/inamen corpora prebuild --force`).

Discovery candidates can start as scan results or alignment diffs before promotion into `Features::CATALOG`.
