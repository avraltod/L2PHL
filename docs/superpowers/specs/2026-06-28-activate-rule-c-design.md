# Activate rule_C — Design Spec

**Date:** 2026-06-28 · **Status:** approved · v1.1 of [[issue-intelligence-core]]. Activates the dormant **C** verdict ("our QC check disagrees with the Kobo skip logic").

## Background

`rule_C` reads `evidence.data["check_gate_refs"]` (the gate variables OUR QC check declares) and fires **C** when the Kobo `relevant` for that variable references gate vars our check ignores — i.e. our check is narrower than the real skip logic and may produce **false** violations. The assembler never populated `check_gate_refs`, so rule_C has been inert. This wires it in.

## Source of check_gate_refs

Each flag's `label` is the QC rule, e.g. `"A1=1, not eligible for A18 (A6∉{1,2,3}; R4+ also A16∉{3,99}) but A18 (pension) is filled"`. The **antecedent** (text before `but`) names the gate variables the check uses. Extract variable-like tokens from it, excluding round tokens (`R4`) and the variable being checked itself.

`_check_gate_refs(flag)`:
- `ant = label.split("but")[0]`
- tokens matching `[A-Za-z]{1,6}\d[A-Za-z0-9_]*` (a letter-prefixed token containing a digit — `A1`, `A16`, `D5a`, `SH2`), lowercased
- drop `r\d+` (round refs) and the flag's own variable (underscore-insensitive)

## Effect on real data (validated)

A18: check-gate `{a1, a6, a16}` vs Kobo-gate `{a1, a6, a16, a24, a26, a27}` → Kobo references `a24/a26/a27` (alternative employment routes) our check ignores → **C fires**. Same for A19. So a18/a19 — currently **proposed A2** (firm field issue) — become **proposed C** (our check is incomplete). This is a real correction: we should not blame the firm for violations our check mis-derives.

**Lifecycle note:** a18/a19 are *seeded* in the registry as A2/acknowledged, so their **effective** verdict stays A2 (the human decision wins) — activation changes only the *proposed* verdict + surfaces the signal. The user decides whether to re-classify them to C (and drop them from the firm tracker). New, unseeded check-vs-kobo cases will propose C and land in the review queue.

## Changes

1. `scripts/issue_evidence.py` — add `_check_gate_refs(flag)`; set `ev.data["check_gate_refs"]`. (Activates rule_C; no classifier change.)
2. `scripts/gen_dashboard.py` — in the evidence drill-in, when the verdict is C, show the check-gate vs the ignored Kobo refs (so the analyst sees *why* C).

## Testing

- `issue_evidence`: TDD — `_check_gate_refs` extracts gate vars from the antecedent, excludes round + self; `assemble_evidence` populates `check_gate_refs`.
- end-to-end: `build_issues` on real data → a18/a19 `proposed_verdict == "C"`, `rule_fired == "check-vs-kobo"`. Classifier suite still green.

## Out of scope

Re-seeding a18/a19 (user decision). Variable-level gate parsing beyond the antecedent heuristic. Tuning rule_C confidence (stays "high").
