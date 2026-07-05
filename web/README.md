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

## Branch

First web release work lives on `web/v1`.
