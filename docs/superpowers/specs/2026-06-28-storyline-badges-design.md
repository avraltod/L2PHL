# Inline Storyline QC Badges — Design Spec

**Date:** 2026-06-28 · **Status:** approved · v2 of sub-project 6 ([[issue-intelligence-core]] grounding). Turns the grounding report into reader-facing data-quality badges in `CATI/Analysis/SL/l2p_cati_story.html`.

## Mechanism (drift-safe)

Storyline claims bind to stats via `<span data-stat="group.subkey" data-fmt="…">value</span>`. `build_story.py`'s injector rewrites only the **inner** of those spans and drift-checks `built == original`. So a badge inserted **immediately after** a span's `</span>` (outside it) is invisible to the injector and the drift-check:

```
…71.7%</span><sup class="qc-caveat" title="Rests on open firm issue: M04/a18…">&#9888;</sup>
```

A one-time `.qc-caveat` CSS rule (amber `⚠`, `cursor:help`) is added to the existing `<style>`.

## Idempotent + live

Each run first **strips** every existing `<sup class="qc-caveat">…</sup>`, then re-adds badges for the **current** caveat set (from grounding). When the firm resolves an issue, the next run removes its badge — the storyline self-heals. A `--clear` flag strips all badges (no caveats).

## Caveat source

Reuse `grounding.ground(_stat_keys(sl_stats), issue_summary, issues)`; a claim is a caveat if `module and not grounded` (rests on an open firm A1/A2/B issue). Tooltip = `"Rests on open firm issue(s): <keys>"`. Today: 7 keys (`employment.{verbal,written,no_contract,dont_know}_a16eq*` → M04 a18/a19; `sample.{total_hh,hh_r1,hh_r3}` → M01 d26_2). Every occurrence of a caveated number is badged.

## Build

- `scripts/storyline_badges.py` — pure `apply_badges(html, caveats) -> html` (+ `_strip_badges`, `_esc`). TDD on a small fixture.
- `scripts/build_storyline_badges.py` — `_caveats()` from grounding; `run(clear=False)` reads/writes `l2p_cati_story.html` in place.
- `scripts/qc_issue.py storyline-badges [--clear]` hook.

## Compatibility

Badges live outside `data-stat` spans, so `build_story.py --check` stays **CHECK OK** (verified baseline). CSS injected once. `apply_badges` is idempotent and reversible.

## Testing

- `storyline_badges`: TDD — badge placed after a caveat span; non-caveat spans untouched; idempotent (run twice == once); `--clear`/empty caveats removes all badges; CSS injected once.
- end-to-end: apply to the real storyline → 7 caveat keys badged; `build_story.py --check` still CHECK OK.

## Out of scope

Badging chart datapoints; a QC legend/banner in the storyline; grounding the CAPI storyline; variable-level precision (still module/round).
