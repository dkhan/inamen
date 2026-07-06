# Inamen Web

Rails 8 front end for the [Inamen](../) text pattern engine.

## Requirements

- Ruby 3.2+ (see `.ruby-version`)
- Bundler
- SQLite (via the `sqlite3` gem — used for Rails cache/jobs and Inamen corpus indexes)

The app loads the engine from the monorepo root (`gem "inamen", path: ".."`) and reads plain-text editions from `../data/`.

---

## Local development

### First-time setup

From this directory:

```bash
bundle install
bin/setup --skip-server
```

`bin/setup` runs `db:prepare`, **prebuilds Inamen corpora** (`bin/rails inamen:corpora:prebuild`), and clears logs/tmp. Pass `--skip-corpora` to skip the corpus build (~1–2 minutes for both editions).

### Run the server

```bash
bin/rails server
```

Open http://localhost:3000

### Manual corpus prebuild

```bash
bin/rails inamen:corpora:prebuild
FORCE=1 bin/rails inamen:corpora:prebuild   # rebuild existing files
```

Or from the repo root (no Rails):

```bash
../bin/inamen corpora prebuild
```

Prebuilt files are written to `../data/corpora/`:

```
data/corpora/{edition_id}-{sha256_prefix}-{indexer_revision}.sqlite
```

The app prefers these files over building into `tmp/corpora/` at runtime.

---

## Application routes

| Path | Description |
|------|-------------|
| `/` | Home — versions, edition checksums |
| `/features` | Feature catalog with edition switcher; cached verification results |
| `/features/:id` | Single feature — definition, KJV Code link, detail lines |
| `/discover` | Discovery scans — word count, divisibility, equal-count groups |

### Features (`/features`)

- Select **kjv_normalized** or **concord**
- Edition choice persists in session across Features and Discover
- **Run verification** / **Recompute** — runs all 18 catalog features; sync when corpus exists, background job otherwise
- Results cached one week under `tmp/cache/`

### Discover (`/discover`)

- **Search Within** — nested checkbox tree (colophons, superscriptions, OT/NT book categories); expand/collapse state saved in `sessionStorage` across rescans
- **Word count** — one term per line; `*` wildcards; `|cs` for case-sensitive
- **Divisible by N** / **Equal occurrence count** — filter by min count and scope
- **Rescan** — clears cached results and re-runs with current settings
- Word-count scans run synchronously when a corpus index exists (~100ms with lexicon)

---

## Production deployment

### 1. Prepare the server

- Ruby 3.2+, Bundler, build tools for native gems (`sqlite3`)
- Clone the full monorepo (engine + `data/` + `web/`)

### 2. Install and prepare

```bash
cd web
bundle install --without development test
export RAILS_ENV=production
export RAILS_MASTER_KEY=<contents of config/master.key>
bin/rails db:prepare
bin/rails inamen:corpora:prebuild
bin/rails assets:precompile
```

**Important:** Run `inamen:corpora:prebuild` on every deploy where the engine version or bundled text files change. Without it, the first user request per edition triggers an on-demand index build (~1 minute).

Set `FORCE=1` to rebuild corpora after an indexer revision bump even when files already exist.

### 3. Start the application

**Single server (Puma + Solid Queue in one process):**

```bash
export SOLID_QUEUE_IN_PUMA=1
bundle exec puma -C config/puma.rb
```

**Puma only** (background jobs use the default adapter unless configured):

```bash
bundle exec puma -C config/puma.rb
```

Configure `PORT`, `RAILS_MAX_THREADS`, and `WEB_CONCURRENCY` as needed.

### 4. Verify

```bash
curl -f http://localhost:${PORT:-3000}/up
```

Visit `/features` and `/discover` — responses should be immediate if prebuilt corpora exist under `data/corpora/`.

### Deploy checklist

| Step | Command / note |
|------|----------------|
| Dependencies | `bundle install` in `web/` |
| Database | `bin/rails db:prepare` |
| **Corpora** | `bin/rails inamen:corpora:prebuild` |
| Assets | `bin/rails assets:precompile` |
| Secrets | `RAILS_MASTER_KEY` in environment |
| Jobs (optional) | `SOLID_QUEUE_IN_PUMA=1` for single-node deploys |
| Health | Monitor `GET /up` |

### Files and persistence

| Path | Purpose |
|------|---------|
| `../data/corpora/*.sqlite` | Prebuilt Inamen indexes (build at deploy; persist across restarts) |
| `tmp/corpora/` | Fallback runtime-built corpora if prebuilt missing |
| `tmp/cache/` | Cached feature verification and discovery scan results (1 week TTL) |
| `storage/` | Active Storage (if used) |
| `log/` | Application logs |

`tmp:clear` does not remove `data/corpora/` prebuilts. Re-run `inamen:corpora:prebuild` after upgrading the gem if `INDEXER_REVISION` changes.

### Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `RAILS_ENV` | Yes | `production` |
| `RAILS_MASTER_KEY` | Yes | Credentials decryption |
| `PORT` | No | Default `3000` |
| `RAILS_LOG_LEVEL` | No | Default `info` |
| `SOLID_QUEUE_IN_PUMA` | No | `1` to run Solid Queue inside Puma |
| `FORCE` | No | `1` when running `inamen:corpora:prebuild` to force rebuild |

---

## Troubleshooting

**First scan or verification is slow** — prebuilt corpora missing. Run `bin/rails inamen:corpora:prebuild` and confirm files exist in `../data/corpora/`.

**Stale discovery or feature results** — click **Rescan** or **Recompute**, or clear `tmp/cache/`.

**Concord vs kjv_normalized counts differ** — expected for some features (e.g. `file_character_total`). Concord uses edition-specific pass targets documented in `lib/inamen/kjv_editions.rb`.

---

## Engine documentation

CLI, feature definitions, corpus indexing, and contributing: **[../README.md](../README.md)**
