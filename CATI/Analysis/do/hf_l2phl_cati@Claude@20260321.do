// L2PHL CATI — Master Processing Script (@Claude version)
// Created by Claude (Anthropic) on behalf of Avralt-Od Purevjav
// Created on: Mar 21, 2026
//
// PURPOSE:
//   Runs all round-level @Claude do-files in the correct order, then
//   runs the master pooling/analysis script to regenerate the pooled
//   Analysis/HF/ datasets.
//
//   @Claude versions differ from @AP versions in two ways:
//     1. glo wd points to ~/iDrive/GitHub/PHL/L2PHL/ (GitHub working folder)
//     2. Systematic skip logic fixes are applied via fix/do/ files:
//          M04: replace a10/a11=. if a1==2  (R1–R5, 497 violations)
//          M04: replace a9=. if inlist(a8,2,99)  (R3 only, 63 violations)
//          M05: replace ia3_a–ia3_f=. if ia2==2  (R4 only, 90 violations)
//
// ORDER:
//   Round 1 Trailer → Round 1 → Round 2 → Round 3 → Round 4 → Round 5
//   → Master pooling (hf_l2phl_analysis@AP@20260320.do)
//
// NOTES:
//   - Trailer must run before Round 1 (activity module recovery data)
//   - Each round do-file internally calls all fix/do/ files for that round
//   - After running this script, re-run the QC pipeline:
//       cd ~/iDrive/GitHub/PHL/L2PHL/CATI/Analysis/QC
//       python3 update_pipeline.py --dta
// ============================================================================

	clear all
	set more off

	// Set root
	loc ow = c(os)
	if ("`ow'"=="MacOSX")  ///
		glo root "~/iDrive/GitHub/PHL/L2PHL"
	if ("`ow'"=="Windows")  ///
		glo root "C:\Users\wb463427\OneDrive - WBG\ECAPOV\L2Ss\L2Ukr\CATI"

	glo cati "$root/CATI"

	di in green "============================================"
	di in green " L2PHL CATI @Claude Processing Pipeline"
	di in green " Root: $root"
	di in green "============================================"

// ── ROUND 1 ──────────────────────────────────────────────────────────────────

	di in green _newline ">>> Step 1/6: Round 1 Trailer"
	do "${cati}/Round01/Round 1 - Trailer/do/L2PHL_CATI@R01_TRAILER@Claude@20251125.do"

	di in green _newline ">>> Step 2/6: Round 1"
	do "${cati}/Round01/do/L2PHL_CATI@R01@Claude@20251125.do"

// ── ROUND 2 ──────────────────────────────────────────────────────────────────

	di in green _newline ">>> Step 3/6: Round 2"
	do "${cati}/Round02/do/L2PHL_CATI@R02@Claude@20251228.do"

// ── ROUND 3 ──────────────────────────────────────────────────────────────────

	di in green _newline ">>> Step 4/6: Round 3"
	do "${cati}/Round03/do/L2PHL_CATI@R03@Claude@20260128.do"

// ── ROUND 4 ──────────────────────────────────────────────────────────────────

	di in green _newline ">>> Step 5/6: Round 4"
	do "${cati}/Round04/do/L2PHL_CATI@R04@Claude@20260228.do"

// ── ROUND 5 ──────────────────────────────────────────────────────────────────

	di in green _newline ">>> Step 6/6: Round 5"
	do "${cati}/Round05/do/L2PHL_CATI@R05@Claude@20260319.do"

// ── POOLING ──────────────────────────────────────────────────────────────────

	di in green _newline ">>> Pooling all rounds → Analysis/HF/"
	do "${cati}/Analysis/do/hf_l2phl_analysis@AP@20260320.do"

// ── DONE ─────────────────────────────────────────────────────────────────────

	di in green _newline "============================================"
	di in green " All rounds processed and pooled."
	di in green " Next: run QC pipeline to refresh dashboard."
	di in green "   cd ~/iDrive/GitHub/PHL/L2PHL/CATI/Analysis/QC"
	di in green "   python3 update_pipeline.py --dta"
	di in green "============================================"
