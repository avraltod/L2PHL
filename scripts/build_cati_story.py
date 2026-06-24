#!/usr/bin/env python3
"""Orchestrate the CATI storyline: [run Stata] -> build -> verify.

  build_cati_story.py            # build + verify from existing sl_stats.json
  build_cati_story.py --stata    # run the Stata master (batch) first
  build_cati_story.py --check     # verify only (no write)

Note on --stata: batch Stata (stata-mp -b) is UNLICENSED on this machine; only
the GUI/MCP Stata is licensed. run_stata() therefore treats a missing/empty log
as a failure and tells you to run the master in your licensed Stata, then re-run
this orchestrator WITHOUT --stata (which works fully in pure Python).
"""
import argparse, os, re, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SL = os.path.join(REPO, "CATI", "Analysis", "SL")
STATA = "/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp"
MASTER = os.path.join(SL, "l2phl_master_analysis.do")
LOG = os.path.join(SL, "l2phl_master_analysis.log")
HTML = os.path.join(SL, "l2p_cati_story.html")
JSON = os.path.join(SL, "sl_stats.json")


def run_stata():
    """Run the Stata master in batch, then verify it actually succeeded.

    Batch Stata returns 0 even on error AND even when unlicensed/headless, so a
    zero exit code is meaningless. We verify via the .log instead:
      (a) an error code `\\nr(N);` in the log  -> STATA ERROR, return 1
      (b) no log or an empty log (the unlicensed/headless case produces no usable
          log) -> tell the user to run the master in licensed Stata, return 1
      (c) a log with no error code             -> success, return 0
    """
    if not os.path.exists(STATA):
        print(f"Stata not found at {STATA}")
        return 1

    subprocess.run([STATA, "-b", "do", MASTER], cwd=SL, check=False)

    # (b) No usable log -> batch Stata did not actually run (likely unlicensed).
    if not os.path.exists(LOG) or os.path.getsize(LOG) == 0:
        print(
            "Batch Stata did not run (binary may be unlicensed/headless). "
            "Run CATI/Analysis/SL/l2phl_master_analysis.do in your licensed "
            "Stata, then re-run this without --stata."
        )
        return 1

    text = open(LOG, encoding="utf-8", errors="replace").read()

    # (a) Stata error code in the log.
    m = re.search(r"\nr\((\d+)\);", text)
    if m:
        print(f"STATA ERROR r({m.group(1)}). Log tail:")
        print("\n".join(text.splitlines()[-20:]))
        return 1

    # (c) Log exists, no error code -> success.
    return 0


def build_story(check):
    args = [sys.executable, os.path.join(SL, "build_story.py"),
            "--html", HTML, "--json", JSON, "--chart-key", "charts"]
    if check:
        args.append("--check")
    return subprocess.run(args, cwd=SL).returncode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stata", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    if args.stata:
        if run_stata() != 0:
            return 1
    if args.check:
        return build_story(check=True)
    # build, then always verify
    if build_story(check=False) != 0:
        return 1
    return build_story(check=True)


if __name__ == "__main__":
    sys.exit(main())
