/*
Research Paper: Labor Market Inequalities in the U.S.

Do File: Part 1 - Data Cleaning & Sample Preparation
Author: Hermogenes David Rios
Prof. Amy Damon
Econometrics
Spring 2025

A 5% simple random sample of PUMA-state geographies is drawn at the GEOGRAPHY level, 
retaining individual within a sampled geography
*/

clear all
set more off

* Define Paths
global path        "/Users/davidrios/Econometrics_Final_Paper"
global rawdata     "$path/Data/raw"
global interim     "$path/Data/interim"
global cleaneddata "$path/Data/clean"

cap mkdir "$interim"
cap mkdir "$cleaneddata"

************************************************************************
****** 1. Load Data & Subsample Geographic Units (PUMAs) **************
************************************************************************

* Load raw IPUMS data
use "$rawdata/IPUMS_data.dta", clear

* Create unique geographic identifier (State + PUMA)
gen puma_state = string(statefip) + "_" + string(puma)
label variable puma_state "Geographic Identifier"

* Reduce to one row per geography so that sampling draws geographies, not people
preserve
    duplicates drop puma_state, force
    keep puma_state
    set seed 381
    sample 5
    save "$interim/sampled_puma_data.dta", replace
restore

* Keep every individual living in a sampled geography
merge m:1 puma_state using "$interim/sampled_puma_data.dta"
keep if _merge == 3
drop _merge

************************************************************************
****** 2. Industry Classification **************************************
************************************************************************

gen industry_name = ""
replace industry_name = "Agriculture & Forestry" if inrange(ind, 170, 290)
replace industry_name = "Mining & Oil"           if inrange(ind, 370, 490)
replace industry_name = "Construction"           if ind == 770
replace industry_name = "Manufacturing"          if inrange(ind, 1070, 3990)
replace industry_name = "Wholesale"              if inrange(ind, 4070, 4590)
replace industry_name = "Retail"                 if inrange(ind, 4670, 5791)
replace industry_name = "Transportation"         if inrange(ind, 6070, 6390) | inrange(ind, 570, 690)
replace industry_name = "Information"            if inrange(ind, 6470, 6781)
replace industry_name = "Finance & Real Estate"  if inrange(ind, 6870, 7190)
replace industry_name = "Professional Services"  if inrange(ind, 7270, 7790)
replace industry_name = "Education & Health"     if inrange(ind, 7860, 8470)
replace industry_name = "Arts"                   if inrange(ind, 8560, 8690)
replace industry_name = "Other Services"         if inrange(ind, 8770, 9290)
replace industry_name = "Public Administration"  if inrange(ind, 9370, 9590)
replace industry_name = "Military"               if inrange(ind, 9670, 9870)
replace industry_name = "Unemployed"             if ind == 9920


encode industry_name, generate(industry_encoded)
label variable industry_encoded "Industry Sector"

************************************************************************
****** 3. Demographic & Employment Sample Restrictions ***************
************************************************************************

* Remove invalid income codes and keep the working-age population (16-66)
drop if inctot == 9999999 | inctot == 9999998 | inctot < 0
drop if hhincome == 9999999 | hhincome == 9999998 | hhincome < 0
drop if age < 16 | age > 66

gen age2 = age^2
label variable age2 "Age Squared"

* Recode Citizenship (0 = Native Citizen, 1 = Naturalized, 2 = Non-Citizen)
recode citizen (0 1 = 0 "Native Citizen") (2 = 1 "Naturalized Citizen") (3 = 2 "Non-Citizen"), gen(citizen_cat)
label variable citizen_cat "Citizenship Status"

* Birthplace Region Classification
gen birthplace_group = ""
replace birthplace_group = "U.S. & Territories" if inrange(bpl, 1, 120)
replace birthplace_group = "Mexico"            if bpl == 200
replace birthplace_group = "Central America"    if bpl == 210
replace birthplace_group = "Caribbean"          if inlist(bpl, 250, 260)
replace birthplace_group = "South America"      if bpl == 300
replace birthplace_group = "Europe"             if inrange(bpl, 400, 499)
replace birthplace_group = "East Asia"          if inrange(bpl, 500, 509)
replace birthplace_group = "Southeast Asia"     if inrange(bpl, 510, 519)
replace birthplace_group = "South Asia"         if inrange(bpl, 520, 550)
replace birthplace_group = "Middle East"        if inrange(bpl, 530, 549)
replace birthplace_group = "Africa"             if bpl >= 600 & bpl < 700
replace birthplace_group = "Oceania"            if bpl >= 700 & bpl < 800
replace birthplace_group = "Other/Unknown"      if bpl >= 800
replace birthplace_group = "North America"      if inlist(bpl, 150, 160, 299)
replace birthplace_group = "Asia"               if bpl == 599

encode birthplace_group, generate(birthplace)
label variable birthplace "Birthplace Region"

* Drop internally inconsistent records
drop if birthplace_group == "U.S. & Territories" & citizen_cat == 2

************************************************************************
****** 4. Inflation Adjustment (Constant 2015 Dollars) ****************
************************************************************************

* Convert nominal earnings/income to constant 2015 dollars
gen incwage_adj  = (incwage * cpi99) * (1 / 0.703)
gen hhincome_adj = (hhincome * cpi99) * (1 / 0.703)

label variable incwage_adj  "Wage in Constant 2015 USD"
label variable hhincome_adj "HH Income in Constant 2015 USD"

* Real federal minimum wage, deflated with the SAME deflator as earnings.
* The federal minimum was $7.25 nominal for every year of this panel
* (2012-2019), but its real value falls over time, so it must be deflated
* year by year rather than held fixed. Used below to trim implausible
* hourly wages.
gen minwage_real = (7.25 * cpi99) * (1 / 0.703)
label variable minwage_real "Federal Minimum Wage (Constant 2015 Dollars)"

************************************************************************
****** 5. Labor Supply: Weeks, Hours, and Annual Hours ****************
************************************************************************

/*
Universe note: UHRSWORK and WKSWORK2 are only defined for respondents who
worked during the PREVIOUS YEAR, which is also the reference period for
INCWAGE. EMPSTAT, by contrast, refers to the CURRENT week. The n/a category
(48.7% of the raw file) is people who did not work last year, not missing
data. Coding those zeros as missing rather than as zero hours is essential:
treating them as zero would put a zero in the denominator of the hourly wage.
*/

* ---- 5a. Weeks worked: interval midpoints ----------------------------
/*
WKSWORK2 is intervalled, so weeks must be imputed. Interval midpoints are
the standard convention in this literature (e.g. Katz-Murphy, Autor-Katz-
Kearney, and the Blau-Kahn gender gap papers all use midpoint imputation).

This introduces measurement error in the denominator of the hourly wage,
which is a known limitation and should be stated in the paper: because the
50-52 bin holds 38% of workers and is assigned a single value, the hourly
wage is noisier for part-year workers than for full-year workers.
*/
gen weeks_worked = .
replace weeks_worked =  7   if wkswork2 == 1   // 1-13 weeks
replace weeks_worked = 20   if wkswork2 == 2   // 14-26 weeks
replace weeks_worked = 33   if wkswork2 == 3   // 27-39 weeks
replace weeks_worked = 43.5 if wkswork2 == 4   // 40-47 weeks
replace weeks_worked = 48.5 if wkswork2 == 5   // 48-49 weeks
replace weeks_worked = 51   if wkswork2 == 6   // 50-52 weeks
* wkswork2 == 0 is n/a (did not work last year) and stays missing.
label variable weeks_worked "Weeks Worked Last Year (interval midpoint)"

* ---- 5b. Usual hours per week ----------------------------------------
* 0 = n/a (did not work last year). Must be missing, never zero.
gen hours_week = uhrswork
replace hours_week = . if uhrswork == 0
label variable hours_week "Usual Hours Worked per Week"

* UHRSWORK is top-coded at 99, meaning "99 or more hours". The top code is
* disproportionately male, so leaving it in biases men's hourly wages DOWNWARD
* and therefore understates the gender gap. Flag it so the sensitivity check
* in 02 can be run with and without these observations.
gen byte hours_topcoded = (uhrswork == 99)
label variable hours_topcoded "Usual Hours Top-Coded at 99+"

* ---- 5c. Annual hours -------------------------------------------------
gen annual_hours = hours_week * weeks_worked
label variable annual_hours "Annual Hours Worked (hours/week x weeks)"

* ---- 5d. Full-time full-year indicator --------------------------------
* The Blau-Kahn convention: >= 35 usual hours/week and >= 50 weeks/year.
* Because weeks are intervalled, ">= 50 weeks" is operationalised as the
* top WKSWORK2 bin (50-52), which is exactly the intended group.
gen byte ftfy = (hours_week >= 35 & wkswork2 == 6) if !missing(hours_week, weeks_worked)
label variable ftfy "Full-Time Full-Year Worker (35+ hrs, 50+ wks)"

label define ftfy_lbl 0 "Not FTFY" 1 "FTFY"
label values ftfy ftfy_lbl

* ---- 5e. Part-time indicator -----------------------------------------
gen byte part_time = (hours_week < 35) if !missing(hours_week)
label variable part_time "Usually Works Part-Time (<35 hrs/week)"

************************************************************************
****** 6. Marital Status and Presence of Young Children ***************
************************************************************************

/*
Both variables are standard controls in the gender wage gap literature and
are currently absent from the specification. The male marriage premium and
the female marriage penalty are large, and they run in OPPOSITE directions
by sex, so marital status should be interacted with sex in 02 rather than
entered additively.
*/

* ---- 6a. Marital status ----------------------------------------------
* "Spouse absent" is grouped with married: the economically relevant margin
* for labor supply is the presence of a spouse, not co-residence. Robustness
* alternative: treat category 2 as previously married.
gen byte marital_status = .
replace marital_status = 1 if inlist(marst, 1, 2)     // married (present or absent)
replace marital_status = 2 if inlist(marst, 3, 4, 5)  // separated/divorced/widowed
replace marital_status = 3 if marst == 6              // never married

label define marital_lbl 1 "Married" 2 "Previously Married" 3 "Never Married"
label values marital_status marital_lbl
label variable marital_status "Marital Status Group"

gen byte married = (marital_status == 1) if !missing(marital_status)
label variable married "Currently Married"

* ---- 6b. Young children in the household ------------------------------
/*
NCHILD counts own children of ANY age; a 24-year-old with an infant and a
58-year-old with an adult child are not the same labor-supply shock. NCHLT5
isolates the margin that actually moves hours. Note both are HOUSEHOLD-based
(own children present in the household), so they miss non-resident children.
*/
gen byte nchlt5_grouped = .
replace nchlt5_grouped = 0 if nchlt5 == 0
replace nchlt5_grouped = 1 if nchlt5 == 1
replace nchlt5_grouped = 2 if nchlt5 >= 2 & !missing(nchlt5)

label define nchlt5_lbl 0 "None" 1 "One" 2 "Two or More"
label values nchlt5_grouped nchlt5_lbl
label variable nchlt5_grouped "Own Children Under 5 in Household"

gen byte has_child_lt5 = (nchlt5 >= 1) if !missing(nchlt5)
label variable has_child_lt5 "Has Own Child Under 5 in Household"

************************************************************************
****** 7. Hourly Wage Construction ************************************
************************************************************************

/*
This is the variable that separates the PRICE of labor from the QUANTITY of
labor. The existing specification uses log annual wage income, which mixes
the two: because women supply fewer paid hours on average, part of the
measured "wage gap" is an hours gap, and in the Oaxaca decomposition it lands
in the UNEXPLAINED component by construction, since hours are not a control.
*/
gen hourly_wage = incwage_adj / annual_hours
label variable hourly_wage "Hourly Wage (Constant 2015 Dollars)"

/*
Hourly wages need trimming at BOTH tails. The denominator is a product of two
imperfectly measured quantities, so small errors in hours produce enormous
errors in the ratio: someone reporting 1 hour/week for 7 weeks with $40,000
of wage income implies an hourly wage in the thousands.

Convention: drop below half the contemporaneous real federal minimum wage and
above $200/hour in 2015 dollars. Both thresholds are deliberately wide - the
aim is to remove arithmetic impossibilities, not to trim the genuine tails of
the distribution.
*/
gen byte wage_implausible = 0
replace wage_implausible = 1 if hourly_wage < (0.5 * minwage_real) & !missing(hourly_wage)
replace wage_implausible = 1 if hourly_wage > 200               & !missing(hourly_wage)
label variable wage_implausible "Hourly Wage Outside Plausible Range"

************************************************************************
****** 8. Sample Restrictions (documented waterfall) ******************
************************************************************************

/*
Restrictions are applied here in one block, with the number of observations
lost at each step displayed, so the sample construction is auditable and can
be reported as a table in the paper's appendix. Every applied econometrics
paper should be able to produce this waterfall on request.
*/

display _newline(2) "=============================================="
display "SAMPLE CONSTRUCTION WATERFALL"
display "=============================================="

local n_start = _N
display "Observations after geographic subsample & age/income screens: " %12.0fc `n_start'

* ---- 8a. Employed with positive wage income ---------------------------
local n_before = _N
keep if empstat == 1 & incwage_adj > 0
local n_drop = `n_before' - _N
local n_left = _N
display "  - not employed / no wage income:  " %12.0fc `n_drop' ///
        "   (remaining: " %12.0fc `n_left' ")"

* ---- 8b. Non-missing labor supply -------------------------------------
/*
IMPORTANT: this restriction is new and it CHANGES THE SAMPLE relative to the
annual-income specification. EMPSTAT is measured in the current week while
UHRSWORK/WKSWORK2 refer to last year, so a person can be employed today but
have no hours recorded for last year. Anyone with positive wage income last
year should in principle have positive hours last year; the residual cases
are reporting inconsistencies. Report this count in the paper.
*/
local n_before = _N
keep if !missing(hours_week, weeks_worked)
local n_drop = `n_before' - _N
local n_left = _N
display "  - missing hours or weeks:         " %12.0fc `n_drop' ///
        "   (remaining: " %12.0fc `n_left' ")"

* ---- 8c. Plausible hourly wage ----------------------------------------
local n_before = _N
keep if wage_implausible == 0
local n_drop = `n_before' - _N
local n_left = _N
display "  - implausible hourly wage:        " %12.0fc `n_drop' ///
        "   (remaining: " %12.0fc `n_left' ")"

local n_final = _N
display "=============================================="
display "FINAL ANALYSIS SAMPLE:               " %12.0fc `n_final'
display "=============================================="

* ---- 8d. Composition of the final sample ------------------------------
display _newline "Full-time full-year share, by sex:"
tab sex ftfy, row nofreq

display _newline "Mean annual hours, by sex:"
tabstat annual_hours, by(sex) stats(mean p50 sd n)

display _newline "Top-coded hours (99+), by sex:"
tab sex hours_topcoded, row nofreq

************************************************************************
****** 9. Save *********************************************************
************************************************************************

/*
All variables are retained rather than an explicit keep list. Keeping the
full extract means 02 and 03 can add controls without re-running the (slow)
cleaning step, and Data/ is gitignored so repository size is not a concern.
compress reclaims the storage cost of the wider file.
*/
compress

/*
Put the analysis variables first so the file is readable in the browser.
Wrapped in capture because this is purely cosmetic: STRATA and CLUSTER are
only present if they were ticked in the IPUMS extract, and a missing variable
here would otherwise abort the run BEFORE the save on the next line.
*/
capture order year statefip puma puma_state perwt strata cluster serial pernum ///
      sex age age2 citizen_cat birthplace educ speakeng rachsing ///
      marital_status married nchild nchlt5_grouped has_child_lt5 ///
      incwage_adj hourly_wage hours_week weeks_worked annual_hours ///
      ftfy part_time hours_topcoded industry_encoded

save "$cleaneddata/clean_data.dta", replace

display _newline "Saved: $cleaneddata/clean_data.dta"
describe, short
