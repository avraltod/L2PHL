# scripts/

Tree-wide maintenance tooling (tracked, unlike `CATI/Analysis/QC/scripts/`).

## tidy.py — file-organization maintenance

```bash
python3 scripts/tidy.py --dry-run                 # writes tidy-manifest.{csv,md}
# review tidy-manifest.md; strike rows you disagree with in tidy-manifest.csv
python3 scripts/tidy.py --apply --csv tidy-manifest.csv
```

- One live file per slot (latest `@AP@`); others move to local `_attic/`.
- Fixes `L2PH`→`L2PHL` prefix typos; renames archive folders to `_attic/`.
- `FLAG` rows need a human decision (no canonical AP file, or two same-date AP files).
- Never deletes; writes a reversible `_attic/.tidy-log.csv`.

Run `python3 -m pytest scripts/tests/ -q` after editing.
