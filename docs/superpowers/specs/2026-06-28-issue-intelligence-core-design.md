# Issue-Intelligence Core — Design

**Date:** 2026-06-28 · **Status:** approved (design) · **Scope:** v1 of the issue-intelligence core for the L2PHL CATI QC dashboard.

## Context

The L2PHL CATI QC dashboard flags data-quality problems (skip violations, mandatory-missing, out-of-range, missingness). But a flag alone doesn't say **where the real issue lives** — in the collected data, the KoboToolbox questionnaire logic, or the firm's do-file processing — nor whether it's even a real issue versus an artifact of our own checks. This session we traced every flag by hand (SH2 = parser bug, M05 R3/R6 = pooler bug, M04 A18 = our check bug, A1/A10 = a firm do-file fix). This core **systematizes that root-cause tracing** and adds an **issue lifecycle** so the dashboard reflects the *current delivery's* quality instead of staying red on old, unfixable rounds.

It is sub-project **1 (+2)** of a larger "new-delivery workflow" (others: 3 orchestration, 4 firm-report generator, 5 dashboard polish, 6 QC→storyline). Those are out of scope here but this core is what they build on.

## Goals / success criteria

1. Every existing dashboard flag carries a **root-cause verdict** (A1/A2/B/C/D) + **owner** + **confidence**, plus the issues the 3-layer reconciliation naturally surfaces.
2. A durable **issue registry** records human/Claude decisions so they persist across deliveries (no re-work).
3. The dashboard shows a **per-round status strip** and a **headline = latest round**, coloured only by **OPEN** issues — so marking an old issue `wontfix`/`accepted` stops it colouring past rounds.
4. Two filtered views fall out for free: a **review queue** (adjudicate) and a **firm-report** feed.

Non-goals (v1): a new proactive discovery battery (cross-variable contradictions etc.); interactive status-setting from the dashboard; the orchestration wrapper and firm-report formatting (sub-projects 3/4).

## Verdict taxonomy

| Code | Meaning | Owner | Example |
|------|---------|-------|---------|
| **A1** | Questionnaire/Kobo logic wrong or missing — form *allowed* the inconsistency | firm questionnaire | gate absent so a contradiction is enterable |
| **A2** | Field/interviewer — Kobo gate is correct but the response violates it | firm field team | A1=2 yet A10/A11 filled |
| **B** | Firm processing/do-file (recode/pooler) | firm do-files | M05 R3/R6 dropped; documented fix not applied |
| **C** | Our QC check / representation bug | us | A18 check ignored R4+ A16 gate; SH2 missing inherited gate |
| **D** | Structural / expected — not a real issue | suppress/annotate | preload-gated, derived income, `_oth`, R8-new, suspend/resume |

**A1 vs A2 test:** is the Kobo gate *missing/wrong* (A1) or *correct-but-violated* (A2)?

## Architecture & data flow

A new pipeline stage **`build_issues.py`** runs between the existing builders and `gen_dashboard`:

```
  dq_data.json ─────┐  (flags: per-round counts, severity)
  kobo_skip_logic ──┤  (effective `relevant` per var per round)
  do_modules.json ──┤  (parsed do-file ops: destring/gen/replace per var)
  HF masters (.dta) ┘  (cross-tabs: does data violate the gate?)
        │
        ▼
  build_issues.py
   ├─ Evidence Assembler  → per flag, the 3-layer evidence
   ├─ Classifier (rules)  → proposed verdict A1/A2/B/C/D + confidence
   └─ merge ⨉ issue_registry.yaml  (confirmed verdict / status / notes)
        │
        ▼
     issues.json  ──►  gen_dashboard.py  (per-round strip, open-issue RAG, drill-in)
                  └─►  firm-report generator (sub-project 4)
```

**Issue identity:** stable key `(module, variable, rule_id)`, with per-round counts attached. The registry tracks this key across deliveries.

**Two artifacts:**
- `issues.json` — machine-generated each run (evidence + proposed verdict). Disposable.
- `issue_registry.yaml` — human/Claude-curated, version-controlled. The durable memory. The classifier only *proposes*; the registry *decides*.

**Review queue:** any flag with low confidence, a proposed-vs-registry conflict, or brand-new → surfaced for adjudication (the hybrid step). Decisions are written back to the registry.

## Classifier rules (priority-ordered; first match wins; each carries confidence)

Filtering artifacts (D, C) **before** blaming data (A/B) is deliberate.

1. **→ D (structural/expected)** · high. Variable matches a known structural pattern: preload-referenced gate (`fmid*`, `round_lastint`); derived/calculated total; `_oth`; not-in-current-Kobo (R8-new); scalar with a same-base dummy family holding the data; paradata/timing. (= the curation rules already built.)
2. **→ C (our check/representation bug)** · high. The flag's own check assumption ≠ the Kobo effective `relevant` (diff the check's gate against `kobo_skip_logic`). e.g., A18/A16, SH2 inherited gate, M08 FIES R6+ items.
3. **→ B (firm processing/do-file)** · high–med. Kobo says the var is asked but it's absent from the pooled data / a round is dropped / a documented do-file fix isn't reflected in the data.
4. **→ A1 (questionnaire logic)** · med. Data violates a constraint **and** the Kobo gate is missing/wrong.
5. **→ A2 (field/interviewer)** · med. Data violates a constraint **but** the Kobo gate is correct and no do-file fix applies.
6. **→ review queue** · novel/low-confidence → adjudicate; write the decision back to the registry (a rule-of-one).

Each rule is a small, independently testable function; the set grows as new patterns appear.

## Registry & lifecycle

Registry entry (`issue_registry.yaml`):

```yaml
M04/a1/skip_a1_a10a11:
  verdict: A2                 # confirmed; overrides classifier on conflict
  owner: firm-field
  status: acknowledged
  report_to_firm: true
  notes: "A1=2 but A10/A11 filled; Kobo gate correct → field. Firm fix
          `replace a10/a11=. if a1==2`, extend to R6-R8 in pooler."
  first_seen: 2026-06-28
  rounds: {R1: resolved, R5: resolved, R8: open}   # optional per-round override
```

Lifecycle states drive colouring:

| OPEN (colours) | CLOSED (visible, no colour) |
|---|---|
| `new` — detected, not adjudicated | `resolved` — fix verified in data |
| `acknowledged` — verdict set, on firm/our queue | `wontfix` — can't fix (data already collected) |
| `fix-pending` — fix applied, awaiting next delivery | `accepted` — confirmed not a real problem (D) |

**Per-round strip colouring:** each round's dot = the worst OPEN issue with a count in that round. Marking an old issue `wontfix` clears that round's dot while keeping the row auditable — the lever that fixes "past rounds stay red." Headline = the latest round's dot.

**Setting status (v1):** classifier *proposes*; decisions recorded in the registry by hand or a tiny `qc-issue set <key> <status>` CLI. (Future: status buttons in the dashboard that write the YAML.)

**Automations:**
- **Auto-verify:** a `fix-pending` issue whose count dropped to expected this delivery → `resolved`; a `resolved` issue whose count returns → `reopened` (regression).
- **Carry-forward:** untouched entries keep their status, so decisions persist with zero re-work.

## Dashboard rendering (the issue layer)

**Module card (overview)** — headline = latest-round dot + per-round strip:

```
┌ M04 · Employment ───────────────── headline ● R8 ┐
│  R1 R2 R3 R4 R5 R6 R7 R8                          │
│  🟢 🟢 ⚪ 🟢 🟢 🟡 🟡 🟢   ← worst OPEN issue/round │
│  2 open (1 firm · 1 ours) · 6 closed             │
└───────────────────────────────────────────────────┘
   ⚪ = closed issue this round (wontfix/accepted) — visible, not coloured
```

**Module page — issue list**, one row per issue, expandable to the 3-layer evidence:

```
A2 ▸ skip · a1→a10/a11   [acknowledged] [firm-field]   R6:62 R7:84 R8:59
   ▾ EVIDENCE
     Data   · 708 rows A1=2 & A10/A11 filled; 696 >0; only 28 worked prior round
     Kobo   · A10/A11 relevant = ${A1}=1   → gate present & CORRECT
     Do-file· pooler has `replace a10/a11=. if a1==2` — R1-R5 only, not R6-R8
     Rule 5 → A2 (field): gate correct but violated · confidence: high
     Action · FIRM — extend the a10/a11 null to R6-R8 in the pooler
```

**Verdict colour = owner** (a small, deliberate palette so colour *means* something — also resolves the current "running out of colours / gray bars" mess): A1/A2 → firm hue, B → firm-do-file hue, C → "ours" hue, D → muted gray. Status is a separate chip.

**Two filtered views** over the same `issues.json`: **Review Queue** (low-confidence/new/conflicting) and **Firm Report** (A1/A2/B ∧ open ∧ report_to_firm).

## Open questions for the implementation plan

- Exact `rule_id` naming convention (map each existing build_dq check to a stable id).
- Do-file evidence depth: `do_modules.json` gives destring/gen/replace per var; deeper recode parsing (regex over the do-files) may be needed for some B-cases — decide the v1 floor.
- Confidence thresholds for the review queue.
- `qc-issue` CLI vs. hand-edited YAML for v1.
