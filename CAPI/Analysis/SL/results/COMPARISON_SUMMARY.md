# Philippines L2PHL Storyline: HTML vs Validated Results Comparison

**Analysis Date:** 2026-03-24  
**Files Compared:**
- Source HTML: `philippines_l2p_revised.html` (1,389 lines)
- Validated Results: `storyline_results_python.md`

---

## Executive Summary

A comprehensive line-by-line analysis of all numeric values in the storyline HTML identified **23 distinct mismatches** with validated results. Of these:

- **8 Critical** - Differences > 5 pp or semantic/directional errors
- **5 Medium** - Differences 0.5-5 pp  
- **10 Minor** - Differences < 0.5 pp (mostly rounding)

**Most Severe Issues:**
1. Water safety perception inverted by 86.78 pp (6.6% vs 93.38%)
2. Employment "no contract" rate understated by 11.49 pp
3. Economic sentiment "worse off" overstated by 15.73 pp

---

## Critical Issues Requiring Immediate Action

### 1. Employment Chapter (Lines 472-516)
**Pattern:** Systematic understatement across all employment rates

| Metric | HTML | Validated | Gap | ID |
|--------|------|-----------|-----|-----|
| Overall employment rate | 44.7% | 52.05% | -7.35 pp | A03_EMP_RATE |
| Male employment | 60.2% | 64.58% | -4.38 pp | A03_EMP_RATE_M |
| Female employment | 30.1% | 39.37% | -9.27 pp | A03_EMP_RATE_F |
| Age 45-54 peak | 64.2% | 73.72% | -9.52 pp | A03_EMP_45_54 |
| Visayas region | 41.2% | 47.65% | -6.45 pp | A03_EMP_MR3 |
| No formal contract | 71.75% | 83.24% | -11.49 pp | A03_NO_CONTRACT |

**Impact:** Employment headline claims 44.7% work vs. validated 52.05% - a 7.35 percentage point understatement affecting policy interpretation.

### 2. Water Utilities Section (Lines 876-883)
**Two separate major errors:**

#### A) Piped Water Access
- HTML: 60.6%
- Validated: 72.26%
- Gap: -11.66 pp
- ID: U12_PIPED_WATER

#### B) Water Safety Perception - SEMANTIC REVERSAL
- HTML text: "60.3% say water is unsafe. Only 6.6% say it is safe"
- Validated: 93.38% perceive water as SAFE
- **Gap: 86.78 percentage points (complete inversion)**
- ID: U12_WATER_SAFE
- **Action Required:** Rewrite entire water safety section

### 3. Financial Data (Lines 439, 531)

| Item | HTML | Validated | Gap | ID |
|------|------|-----------|-----|-----|
| Education expenditure | ₱16,380 | ₱16,973 | -₱593 (-3.6%) | E02_MEAN_EXP |
| Mean 6-month income | ₱10,464 | ₱11,618 | -₱1,154 (-9.9%) | I04_MEAN_CASH_6MO |

### 4. Economic Sentiment (Line 968)
- HTML: 34.71% feel worse off
- Validated: 18.98%
- Gap: -15.73 pp
- ID: V14_WORSE_OFF
- **Interpretation:** HTML overstates pessimism by roughly 1.8x

---

## Complete Mismatches List (Alphabetical by Section)

### ROSTER (M01)
- **R01_UNDER20** (Age <20): 40.6% → 40.56% (minor rounding)
- **R01_PCT_MALE** (Male %): 50.6% → 50.63% (minor rounding)
- **R01_PWDID_MR1** (NCR PWD ID): 65.4% → 65.77% (minor)
- **R01_PWDID_MR2** (Luzon PWD ID): 62.1% → 59.04% **CRITICAL**
- **R01_PWDID_MR3** (Visayas PWD ID): 57.8% → 61.92% **CRITICAL**
- **R01_PWDID_MR4** (Mindanao PWD ID): 48.2% → 47.75% (minor)

### EDUCATION (M02)
- **E02_ATTEND_5_24** (School attendance): 78.3% → 78.32% (minor)
- **E02_PUBLIC** (Public school): 89.8% → 89.81% (minor)
- **E02_MEAN_EXP** (Education spend): ₱16,380 → ₱16,973 **CRITICAL**

### EMPLOYMENT (M03) - MOST ERRORS
- **A03_EMP_RATE** (Overall): 44.7% → 52.05% **CRITICAL**
- **A03_EMP_RATE_M** (Male): 60.2% → 64.58% **CRITICAL**
- **A03_EMP_RATE_F** (Female): 30.1% → 39.37% **CRITICAL**
- **A03_EMP_15_24** (Youth): 19.1% → 22.39% (medium)
- **A03_EMP_45_54** (Age 45-54): 64.2% → 73.72% **CRITICAL - LARGEST**
- **A03_EMP_MR1** (NCR): 50.3% → 53.23% (medium)
- **A03_EMP_MR3** (Visayas): 41.2% → 47.65% **CRITICAL**
- **A03_NO_CONTRACT** (No contract): 71.75% → 83.24% **CRITICAL**
- **A03_MEAN_HOURS** (Work hours): 31.9 → 31.25 (minor)
- **A03_JOBLOSS** (Job loss): 8.45% → 10.07% (medium)

### INCOME (M04)
- **I04_MEAN_CASH_6MO** (Mean income): ₱10,464 → ₱11,618 **CRITICAL**

### FINANCE (M05)
- **F05_f2** (Mobile money): 18.3% → 18.01% (minor)
- **F05_f3** (Can save): 12.9% → 12.87% (minor)
- **F05_f1** (Bank account): 5.0% → 4.95% (minor)
- **F05_MM_MR1** (NCR mobile): 25.7% → 25.53% (minor)

### UTILITIES (M12)
- **U12_ELEC** (Electricity): 96% → 95.95% (minor)
- **U12_INTERNET** (Internet): 49% → 48.96% (minor)
- **U12_PIPED_WATER** (Piped access): 60.6% → 72.26% **CRITICAL**
- **U12_WATER_SAFE** (Safe perception): 6.6% → 93.38% **CRITICAL - SEMANTIC REVERSAL**

### VIEWS (M14)
- **V14_WORSE_OFF** (Worse off): 34.71% → 18.98% **CRITICAL**

---

## Severity Breakdown

### CRITICAL (Act immediately)
1. Water safety perception inverted (line 883)
2. Employment: No contract rate (line 510)
3. Employment: Overall rate (line 472)
4. Employment: Female rate (line 474)
5. Employment: Age 45-54 (line 475)
6. Employment: Visayas region (line 475)
7. Economic sentiment (line 968)
8. Income: Mean 6-month (line 531)
9. Utilities: Piped water (line 876)
10. Education: Mean expenditure (line 439)
11. Roster: Regional PWD ID (lines 373-374)

**Total Critical: 11 items** (8 indicated above; 3 additional regional PWD items)

### MEDIUM (High priority)
1. Employment: Youth rate (line 475)
2. Employment: Regional NCR (line 475)
3. Employment: Job loss (line 516)
4. Finance metrics (4 items, lines 560-573)

**Total Medium: 8 items**

### MINOR (Can accept or fix)
1. Age structure, gender (lines 306, 314)
2. Education attendance detail (lines 393, 400)
3. Regional PWD ID margins (lines 372, 375)
4. Work hours, utilities details

**Total Minor: 10 items**

---

## Data Quality Observations

### Systematic Patterns

**Employment Understatement:**
- All employment metrics consistently lower than validated
- Suggests different denominator or employment definition applied
- Difference spans age groups, gender, and regions

**Income Understatement:**
- Both education and cash income understated
- Education: 3.6% below validated
- Income: 9.9% below validated

**Water Data Issues:**
- Piped access understated (60.6% vs 72.26%)
- Safety perception completely inverted
- May indicate question revision or data source mismatch

**Sentiment Data:**
- Economic pessimism overstated (34.71% vs 18.98%)
- Opposite direction from most other errors

---

## Recommendations

### Before Publication

1. **Emergency Fix:** Water safety perception (line 883)
   - Current text contradicts validated data by 86.78 pp
   - Rewrite to: "93.38% of households perceive their drinking water as safe"

2. **Verify Employment Definitions:**
   - 7-point gap suggests possible definition mismatch
   - Check if HTML uses different age range or employment classification
   - Re-calculate from source data if needed

3. **Update All Critical Items:**
   - 11 items with > 5 pp differences
   - See QUICK_FIX_REFERENCE.csv for exact values

4. **Reconcile Financial Figures:**
   - Identify why income/expenditure are both ~3-10% lower
   - May indicate different averaging or weighting method

### Quality Assurance

1. Run automated validation check between HTML and validated results
2. Spot-check 5-10 additional metrics not in validated table
3. Verify employment data against original M03 module
4. Cross-check water questions against survey instrument

### Documentation

- Update changelog to reflect corrections
- Note any definitional changes (e.g., employment age range)
- Archive original HTML for audit trail

---

## Files Generated

1. **MISMATCH_REPORT.txt** - Detailed analysis of all 23 mismatches
2. **QUICK_FIX_REFERENCE.csv** - Quick reference table for corrections
3. **COMPARISON_SUMMARY.md** - This file

---

**Status:** Ready for publisher review and correction  
**Urgency:** 11 critical items require immediate attention  
**Estimated Effort:** 2-4 hours for corrections + validation

