#!/usr/bin/env python3
"""Preflight + verification for the L2PHL reproducibility pipelines.

Checks that the data each pipeline needs is present, runs the drift gates that
work today, and prints the exact next step for the data-gated parts. Run from
anywhere:  python3 scripts/verify_repro.py

What it verifies:
  CATI storyline : build_cati_story.py --check  (HTML vs sl_stats.json)
  CAPI storyline : build_capi_story.py --check  (HTML vs storyline_results_stata.md)

Data prerequisites for the FULL end-to-end run (regenerate numbers from data):
  CATI : CATI/Analysis/HF/l2phl_M08_fies.dta   (FIES module — currently missing)
  CAPI : CAPI/Round00/dta/*.dta                (baseline microdata — gitignored/absent)
See memory `repro-stata-data-prereqs` and WORKFLOW.md.
"""
import os, glob, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIES = os.path.join(REPO, "CATI", "Analysis", "HF", "l2phl_M08_fies.dta")
R00 = os.path.join(REPO, "CAPI", "Round00", "dta")
CATI_BUILD = os.path.join(REPO, "scripts", "build_cati_story.py")
CAPI_BUILD = os.path.join(REPO, "scripts", "build_capi_story.py")


def _line(label, ok, detail=""):
    mark = "OK " if ok else "-- "
    print(f"  [{mark}] {label}{(' — ' + detail) if detail else ''}")


def _check(build_script):
    r = subprocess.run([sys.executable, build_script, "--check"],
                       cwd=REPO, capture_output=True, text=True)
    last = (r.stdout.strip().splitlines() or [""])[-1]
    return r.returncode == 0, last


def main():
    print("L2PHL reproducibility — verification\n")

    print("Drift gates (HTML matches its source artifact):")
    c_ok, c_msg = _check(CATI_BUILD)
    _line("CATI storyline --check", c_ok, c_msg)
    p_ok, p_msg = _check(CAPI_BUILD)
    _line("CAPI storyline --check", p_ok, p_msg)

    print("\nData for the full end-to-end run (regenerate numbers from .dta):")
    fies_ok = os.path.exists(FIES)
    r00_ok = bool(glob.glob(os.path.join(R00, "*.dta")))
    _line("CATI FIES dataset (l2phl_M08_fies.dta)", fies_ok,
          "present" if fies_ok else "MISSING — CATI master can't run end-to-end")
    _line("CAPI Round00 microdata (CAPI/Round00/dta/*.dta)", r00_ok,
          "present" if r00_ok else "MISSING — CAPI replication can't run")

    print("\nNext steps:")
    if fies_ok:
        print("  CATI: run the master, then re-check —")
        print("    stata -b do CATI/Analysis/SL/l2phl_master_analysis.do   (GUI/MCP; batch is unlicensed)")
        print("    python3 scripts/build_cati_story.py --check")
    else:
        print("  CATI: add l2phl_M08_fies.dta to CATI/Analysis/HF/, then re-run this.")
    if r00_ok:
        print("  CAPI: run the replication, then re-check —")
        print("    stata -b do CAPI/Analysis/SL/do/11_L2PHL_CAPI_R00_replication.do")
        print("    python3 scripts/build_capi_story.py --check")
        print("  Then reconcile the 3 flagged discrepancies (memory: capi-story-md-divergences).")
    else:
        print("  CAPI: populate CAPI/Round00/dta/ with the baseline module .dta, then re-run this.")

    # exit non-zero if either drift gate failed (CI-friendly)
    return 0 if (c_ok and p_ok) else 1


if __name__ == "__main__":
    sys.exit(main())
