#!/usr/bin/env python3
"""Orchestrate the CAPI baseline storyline: [run replication.do] -> build -> verify.

  build_capi_story.py            # build + verify from existing storyline_results_stata.md
  build_capi_story.py --stata    # run 11_..._replication.do (batch) first
  build_capi_story.py --check     # verify only
"""
import argparse, os, re, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SL = os.path.join(REPO, "CAPI", "Analysis", "SL")
STATA = "/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp"
REPL = os.path.join(SL, "do", "11_L2PHL_CAPI_R00_replication.do")
ENTRY = os.path.join(SL, "build_capi_story.py")


def run_stata():
    if not os.path.exists(STATA):
        print(f"Stata not found at {STATA}; run 11_..._replication.do in your Stata, then re-run without --stata.")
        return 1
    subprocess.run([STATA, "-b", "do", REPL], cwd=os.path.join(SL, "do"), check=False)
    log = os.path.join(SL, "do", "11_L2PHL_CAPI_R00_replication.log")
    if not os.path.exists(log) or os.path.getsize(log) == 0:
        print("Batch Stata did not run (binary may be unlicensed/headless). "
              "Run CAPI/Analysis/SL/do/11_L2PHL_CAPI_R00_replication.do in your licensed Stata, "
              "then re-run this without --stata.")
        return 1
    text = open(log, encoding="utf-8", errors="replace").read()
    m = re.search(r"\nr\((\d+)\);", text)
    if m:
        print(f"STATA ERROR r({m.group(1)}). Log tail:")
        print("\n".join(text.splitlines()[-20:]))
        return 1
    return 0


def build(check):
    args = [sys.executable, ENTRY]
    if check:
        args.append("--check")
    return subprocess.run(args, cwd=SL).returncode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stata", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    if args.stata and run_stata() != 0:
        return 1
    if args.check:
        return build(check=True)
    if build(check=False) != 0:
        return 1
    return build(check=True)


if __name__ == "__main__":
    sys.exit(main())
