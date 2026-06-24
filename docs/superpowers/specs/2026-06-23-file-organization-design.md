# L2PHL File-Organization Cleanup — Design Spec

**Date:** 2026-06-23
**Author:** AP (Avralt-Od Purevjav)
**Scope:** Part A of a two-part workflow-optimization effort. Part A = folder/file organization (this spec). Part B = reproducibility/pipeline (separate spec, to follow).
**Status:** Approved design → ready for implementation plan.

## Problem

Working folders across `CATI/` and `CAPI/` have accumulated version sprawl and inconsistent conventions, making "what is current" unclear:

- **Naming drift.** Files use `L2PHL_<MODE>@<ROUND>@<AUTHOR>@<DATE>.ext`, but the project prefix sometimes drops a letter (`L2PH` vs `L2PHL`, ~23 files), and four author tags appear (`AP`, `BB`, `CV`, `Claude`).
- **Version proliferation in live folders.** Multiple dated copies of the same logical file sit side by side (e.g. 8 dated `hf_l2phl_analysis@AP@*.do` in `CATI/Analysis/do/`), plus `_v2`/`_v3`/`_old`/`_new`/`_backup` suffixes (~26 files).
- **Archive-folder zoo.** The same "old stuff" concept is spelled seven ways across ~37 folders: `zzz`, `zArc`, `arch`, `arc`, `_arc`, `_DA`, `Attic (Old versions)`, `archive`.

Scale: ~171 `@`-pattern code files (113 `@AP@`, 58 non-AP), 23 `L2PH` typos, 26 version-suffixed files, 37 existing archive folders.

## Decisions (locked)

1. **Canonical author = `@AP@`.** Non-AP variants (`@Claude@`, `@BB@`, `@CV@`) are non-canonical.
2. **Latest date wins.** Where several dated `@AP@` copies of one slot exist, the newest is live; older ones are superseded.
3. **Disposition = archive, never delete.** Non-canonical and superseded files move to an archive; nothing is removed from disk by this effort.
4. **Archive is local.** A `_attic/` folder inside each working directory (not one central archive).
5. **Archive name = `_attic/`.** Single spelling; retire `zzz`/`zArc`/`arch`/`arc`/`_arc`/`_DA`/`Attic`/`archive`.
6. **Naming pattern kept and enforced:** `L2PHL_<MODE>@<ROUND>@AP@YYYYMMDD.ext` — prefix always `L2PHL`, author always `AP`, date = revision date, one live date per slot.
7. **Scope = whole tree, all file types:** `.do`, `.R`, `.json`, `.html`, `.docx`, `.txt`.
8. **Delivery = doc + re-runnable script + reviewable one-time migration manifest.**

## Design

### Section 1 — The convention

A new auto-loaded rule file **`.claude/rules/file-organization.md`** codifying:

- **Canonical-file rule.** Exactly one live file per *slot* (a logical role: a round's master do-file, an analysis script, a stats JSON, a deliverable). The live file is the latest-dated `@AP@` version. Everything else is *superseded* and belongs in `_attic/`.
- **Naming pattern.** `L2PHL_<MODE>@<ROUND>@AP@YYYYMMDD.ext`. Prefix always `L2PHL` (fixes 23 typos); author always `AP`; date = revision date. Bumping the date moves the prior file to `_attic/`. Applies tree-wide to `.do`, `.R`, `.json`, `.html`, `.docx`, `.txt`.
- **Archive rule.** Superseded files go to a `_attic/` folder local to their working directory (e.g. `CATI/Round02/do/_attic/`). One spelling only.
- **`.gitignore` change.** Replace the five archive lines (`**/zzz/`, `**/zArc/`, `**/arch/`, `**/arc/`, `**/Attic*/`) with a single `**/_attic/`.

### Section 2 — The tooling

Two entry points sharing one core library (so dry-run and apply never disagree). Location: `CATI/Analysis/QC/scripts/` or a new top-level `scripts/` (decided at planning time).

**`tidy.py --dry-run` → migration manifest (one-time big sweep).**
Walks the whole tree and emits a reviewable manifest (`docs/superpowers/specs/2026-06-23-tidy-manifest.md` + machine-readable `.csv`), one row per proposed action, grouped for chunked approval:

| Action | Trigger |
|--------|---------|
| `RENAME` | `L2PH` → `L2PHL` prefix typo |
| `ARCHIVE` | non-AP author (`@Claude@`/`@BB@`/`@CV@`) |
| `ARCHIVE` | superseded older-dated `@AP@` file |
| `ARCHIVE` | `_v2`/`_v3`/`_old`/`_new`/`_backup` suffix |
| `RENAME-DIR` | archive-folder spelling → `_attic/` |
| `FLAG` | ambiguous — two same-date AP candidates, unrecognized naming |

Nothing moves on a dry run. User reviews, strikes disagreed rows, then applies.

**`tidy.py --apply [--manifest <file>]` → executes the approved manifest.**
Safety properties:
- **git-aware** — `git mv` for tracked files (history follows); plain move for ignored ones.
- **never deletes** — only moves to `_attic/` or renames.
- **idempotent** — re-running on a clean tree is a no-op.
- **collision-safe** — suffixes rather than overwrites if a target already exists in `_attic/`.
- **undo log** — writes `_attic/.tidy-log.csv` so any sweep is reversible.

**Ongoing use.** Each new round: `tidy.py --dry-run` → glance at the (now-small) manifest → `--apply`. The `FLAG` category surfaces genuinely ambiguous cases for a human rather than guessing.

**Out of scope (deliberately):** deciding content questions (which of two same-date files is "better"); touching `.dta`/`raw/`/`aud/` data (gitignored, left alone); reorganizing the directory taxonomy itself (that is Part B, reproducibility).

## Acceptance criteria

- `rules/file-organization.md` exists and is auto-loaded.
- `.gitignore` archive lines collapsed to `**/_attic/`.
- `tidy.py` produces a dry-run manifest covering the full `CATI/` + `CAPI/` tree.
- Applying the manifest leaves exactly one live file per slot, all archive folders named `_attic/`, all `L2PH` typos fixed, and an undo log written.
- Re-running `--dry-run` on the cleaned tree yields an empty (no-action) manifest.

## Next

After this is implemented and the tree is clean, Part B (reproducibility/pipeline) gets its own brainstorm → spec, building on the now-stable file layout.
