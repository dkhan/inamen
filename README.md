# Inamen — KJV text counter

## Overview

**Inamen** reads the plain-text King James Bible (`data/KJV.txt`), walks it line by line with a deterministic state machine, and counts **tokens** (Unicode words and ASCII digit runs) into fixed buckets. When every bucket is summed with [`CountingService.combined_total`](lib/inamen/counting_service.rb), the result is **823,543** — that is **7⁷**, matching the target used for verification.

Parsing rules are explicit and **reproducible**: the same file always yields the same totals. Tokenization, chapter/verse boundaries, Psalm titles, implicit verse 1, superscriptions, Psalm 119 stanza labels, and a few KJV layout quirks (for example split verse-1 lines in Isaiah) are all handled in code, not by ad hoc editing of the source text.

## Features

- **Tokenization** — Letter-based words per [`Tokenizer`](lib/inamen/tokenizer.rb), including internal hyphens and **both** apostrophes: ASCII `'` (U+0027) and curly `’` (U+2019). Digit-only lines are counted as numeric tokens where the parser treats them as chapter or verse markers.
- **Bucketed counts** — Separates **verse body** words from **non-verse text** (titles, colophons, etc.), **Psalm heading** words, **Psalm 119 division** words, chapter markers, and verse numbers, so the combined total matches the known check value.
- **Psalm-aware logic** — [`CountingService`](lib/inamen/counting_service.rb) handles `PSALM n` chapter titles, optional superscriptions, implicit first verses, stanza labels in Psalm 119, and lookahead when verse 1 is not numbered on the line.
- **Debug CLI** — Subcommands under `bin/inamen` help trace mismatches (book/chapter/verse totals, numeric chapter lines, text-word sources, Psalm headings, and classifier samples).
- **Regression tests** — RSpec examples for parsing edge cases plus a **full-file** spec on `data/KJV.txt` that locks all bucket totals and internal debug identities.

## Installation

1. **Ruby** — Use a current **Ruby 3.1+** (no version is pinned in the repo; 3.2 or 3.3 is typical).

2. **Dependencies**

   ```bash
   bundle install
   ```

3. **Data** — Ensure `data/KJV.txt` is present (the default input for the CLI and full KJV spec).

No further setup is required.

## Usage

Run the main counter on the bundled KJV file (prints all buckets, debug fields, combined total, and divisibility by 7):

```bash
./bin/inamen
```

If the script is not executable:

```bash
chmod +x bin/inamen
```

Or invoke Ruby explicitly:

```bash
ruby bin/inamen
```

### Other commands

| Command | Purpose |
|--------|---------|
| `ruby bin/inamen` | Default: full counts for `data/KJV.txt` |
| `ruby bin/inamen book-stats-debug` | Per-book chapters/verses vs canon (mismatches only; add `--all` for every book) |
| `ruby bin/inamen text-words-debug` | Lines that contribute to non-verse `text_words` |
| `ruby bin/inamen psalm-heading-words-debug` | Lines that contribute to `psalm_heading_words` |
| `ruby bin/inamen psalms-unclassified-debug` | Residual `unclassified_text` lines in the Psalms span (context lines) |
| `ruby bin/inamen numeric-chapters-debug` | Digit-only lines treated as chapter markers |
| `ruby bin/inamen line-samples [N]` | Sample lines per [`LineClassifier`](lib/inamen/line_classifier.rb) category |
| `ruby bin/inamen psalm-debug` | Each `PSALM n` line with the next two non-empty lines and classifications |

### Tests

```bash
bundle exec rspec
```

The example **matches full KJV totals (7⁷)** in `spec/inamen/counting_service_full_kjv_spec.rb` asserts the canonical bucket totals and `combined_total == 823_543` on the full file.
