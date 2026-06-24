# File-organization rules

**One live file per slot.** A *slot* is a logical role (a round master do-file,
an analysis script, a stats JSON, a deliverable). Exactly one live file per slot:
the latest-dated `@AP@` version. Everything else is superseded.

**Naming.** `L2PHL_<MODE>@<ROUND>@AP@YYYYMMDD.ext`. Prefix is always `L2PHL`
(never `L2PH`); author is always `AP`; date is the revision date. Bumping the
date moves the prior file to `_attic/`. Applies to `.do .R .json .html .docx .txt`.

**Archive.** Superseded files go to a `_attic/` folder local to their working
directory (e.g. `CATI/Round02/do/_attic/`). `_attic/` is the only archive name —
`zzz` `zArc` `arch` `arc` `_arc` `_DA` `Attic*` `archive` are retired.

**Maintenance.** Run `python3 scripts/tidy.py --dry-run`, review the manifest,
then `python3 scripts/tidy.py --apply --csv tidy-manifest.csv`. Re-run every round.
