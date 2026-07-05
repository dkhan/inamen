# Inamen Web

Rails 8 front end for the [Inamen](../) text pattern engine.

## Setup

From this directory:

```bash
bundle install
bin/rails db:prepare
```

The app loads the `inamen` gem from the monorepo root (`gem "inamen", path: ".."`) and reads bundled corpora from `../data/`.

## Run

```bash
bin/rails server
```

Open http://localhost:3000 — Phase 0 home page lists engine version, catalog feature count, and bundled KJV editions.

### Features catalog (Phase 1)

- `/features` — all 18 catalog features with live counts vs expected (edition selector, cached results)
- `/features/:id` — definition, notes, KJV Code alignment, and detail lines

First verification run builds the SQLite corpus and may take several minutes; results cache under `tmp/cache/` for one week.

## Branch

Feature catalog work lives on `web/features`.
