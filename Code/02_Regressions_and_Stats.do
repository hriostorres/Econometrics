/*
Research Paper: Labor Market Inequalities in the U.S.

Do File: Part 2 - Descriptive Statistics, Regressions & Oaxaca Decomposition
Author: Hermogenes David Rios
Prof. Amy Damon
Econometrics
Spring 2025

Preferred specification:
  ln_wage on citizenship x sex interaction, age, age squared (centered),
  education group, English fluency group, number-of-children group, and
  race/ethnicity (rachsing), plus year, industry, birthplace, and
  PUMA-state fixed effects. Standard errors clustered on the 118
  PUMA-state geographies.

Main models are UNWEIGHTED.

* Oaxaca decomposition (two-fold, pooled refs with group indicator)
* Uses standard regression controls, EXCLUDING:
* 1. PUMA-state FEs (too high dimension: 118 dummies)
* 2. Birthplace FEs (defines group in citizenship model)
* 3. Race indicators (prevents assigning race pay gaps to "explained" productivity)

These exclusions are documented in the paper's methodology section.
*/

clear all
set more off

* Ensure required packages are installed
cap ssc install reghdfe
cap ssc install ftools
cap ssc install outreg2
cap ssc install oaxaca

* Define Master Project Paths
* $path is the ONLY line a replicator needs to edit; it must match the value
* set in 01_Data_Cleaning.do. Directory names are case-correct so the scripts
* also run on Linux, where the filesystem is case-sensitive.
global path        "/Users/davidrios/Econometrics_Final_Paper"
global cleaneddata "$path/Data/clean"
global tables      "$path/Output/tables"

* Create output directories
cap mkdir "$path/Output"
cap mkdir "$tables"

* Load cleaned dataset produced by Part 1
use "$cleaneddata/clean_data.dta", clear

************************************************************************
****** 1. Variable Transformation & Recoding ***************************
************************************************************************

* Dependent Variable
gen ln_wage = log(incwage_adj)
label var ln_wage "Log Wage (2015$)"

* Numeric cluster identifier 
egen cluster_id = group(puma_state)
label var cluster_id "PUMA-State Cluster ID"

* Center Age at the (unweighted) sample mean
sum age, meanonly
gen age_c    = age - r(mean)
gen age_c_sq = age_c^2
label var age_c    "Age (centered at mean)"
label var age_c_sq "Age Squared (centered at mean)"

* Education Groups 
gen educ_grouped = .
replace educ_grouped = 1 if inlist(educ, 0, 1, 2, 3, 4, 5, 6)
replace educ_grouped = 2 if inlist(educ, 7, 8, 9)
replace educ_grouped = 3 if inlist(educ, 10, 11)
label define educgrp 1 "HS or Less" 2 "Some College" 3 "Bachelor's or Higher"
label values educ_grouped educgrp
label var educ_grouped "Educational Attainment Group"

* English Fluency Groups
gen eng_fluency = .
replace eng_fluency = 1 if inlist(speakeng, 3, 4) // Fluent (Only English / Very Well)
replace eng_fluency = 2 if inlist(speakeng, 2, 5) // Intermediate (Speaks Well)
replace eng_fluency = 3 if inlist(speakeng, 1, 6) // Limited (Not Well / Not at All)
label define englbl 1 "Fluent" 2 "Intermediate" 3 "Limited"
label values eng_fluency englbl
label var eng_fluency "English Fluency Group"

* Children Groups
gen nchild_grouped = .
replace nchild_grouped = 0 if nchild == 0
replace nchild_grouped = 1 if nchild == 1
replace nchild_grouped = 2 if nchild == 2
replace nchild_grouped = 3 if inlist(nchild, 3, 4)
replace nchild_grouped = 4 if inrange(nchild, 5, 9)
label define nchildgrp 0 "None" 1 "One" 2 "Two" 3 "Three-Four" 4 "Five+"
label values nchild_grouped nchildgrp
label var nchild_grouped "Number of Children Group"

* Binary Citizen Indicator (1 = Non-Citizen, 0 = Citizen)
gen byte non_citizen = (citizen_cat == 2)
label var non_citizen "Non-Citizen Indicator"

* Intersectional Groupings
gen byte citizen_sex = .
replace citizen_sex = 0 if citizen_cat == 2 & sex == 2 // Non-Citizen Female
replace citizen_sex = 1 if citizen_cat != 2 & sex == 2 // Citizen Female
replace citizen_sex = 2 if citizen_cat == 2 & sex == 1 // Non-Citizen Male
replace citizen_sex = 3 if citizen_cat != 2 & sex == 1 // Citizen Male
label define citizen_sex_lbl 0 "Non-Citizen Female" 1 "Citizen Female" 2 "Non-Citizen Male" 3 "Citizen Male"
label values citizen_sex citizen_sex_lbl

************************************************************************
****** 2. Descriptive Statistics (Appendix Tables) *********************
************************************************************************

tab citizen_cat
tab sex
tab citizen_cat sex, sum(incwage_adj) means

* Median wages by citizenship and sex
table citizen_cat sex, statistic(median incwage_adj)

* Industry distribution of non-citizen workers
tab industry_encoded if citizen_cat == 2

************************************************************************
****** 3. Regression Specifications (Unweighted vs. Weighted) **********
************************************************************************

* Preferred controls. hhincome_adj is intentionally excluded (bad control).
* Race (rachsing: White ref., Black, AIAN, Asian/PI, Hispanic/Latino) is
* included ALONGSIDE birthplace FE: birthplace absorbs origin-country
* factors, race absorbs racial stratification within and across origins.
global controls age_c age_c_sq i.educ_grouped i.eng_fluency i.nchild_grouped i.rachsing

* Loop through weighting options (unweighted = main, weighted = robustness)
foreach wt in unw w {

    if "`wt'" == "unw" {
        local wvar ""
    }
    else {
        local wvar "[pw = perwt]"
    }

    * Model 1: Unadjusted Gender & Citizenship Interactions
    reg ln_wage i.citizen_cat##i.sex `wvar', vce(cluster cluster_id)
    estimates store m1_`wt'

    * Model 2: Adding Human Capital & Demographic Controls
    reg ln_wage i.citizen_cat##i.sex $controls `wvar', vce(cluster cluster_id)
    estimates store m2_`wt'

    * Model 3 (PREFERRED): Full High-Dimensional Fixed Effects Model
    reghdfe ln_wage i.citizen_cat##i.sex $controls `wvar', ///
        absorb(year industry_encoded puma_state birthplace) vce(cluster cluster_id)
    estimates store m3_`wt'
}

* Main table: unweighted Models 1-3, core coefficients
outreg2 [m1_unw] using "$tables/wage_regressions_main.doc", replace ///
    ctitle("Model 1") title("Effect of Gender and Citizenship on Log Wages") ///
    dec(3) se label word ///
    keep(1.citizen_cat 2.citizen_cat 2.sex 1.citizen_cat#2.sex 2.citizen_cat#2.sex)
outreg2 [m2_unw] using "$tables/wage_regressions_main.doc", append ctitle("Model 2") ///
    dec(3) se label word ///
    keep(1.citizen_cat 2.citizen_cat 2.sex 1.citizen_cat#2.sex 2.citizen_cat#2.sex)
outreg2 [m3_unw] using "$tables/wage_regressions_main.doc", append ctitle("Model 3") ///
    dec(3) se label word ///
    keep(1.citizen_cat 2.citizen_cat 2.sex 1.citizen_cat#2.sex 2.citizen_cat#2.sex)

* Appendix table: full coefficient listing 
outreg2 [m1_unw] using "$tables/wage_regressions_full.doc", replace ///
    ctitle("Model 1") title("Full Coefficient Estimates, All Models") ///
    dec(3) se label word
outreg2 [m2_unw] using "$tables/wage_regressions_full.doc", append ctitle("Model 2") ///
    dec(3) se label word
outreg2 [m3_unw] using "$tables/wage_regressions_full.doc", append ctitle("Model 3") ///
    dec(3) se label word

* Appendix table: unweighted vs. population-weighted Model 3
outreg2 [m3_unw] using "$tables/weighted_robustness.doc", replace ///
    ctitle("Unweighted") title("Model 3: Unweighted vs. Population-Weighted (ACS perwt)") ///
    dec(3) se label word ///
    keep(1.citizen_cat 2.citizen_cat 2.sex 1.citizen_cat#2.sex 2.citizen_cat#2.sex)
outreg2 [m3_w] using "$tables/weighted_robustness.doc", append ctitle("Weighted") ///
    dec(3) se label word ///
    keep(1.citizen_cat 2.citizen_cat 2.sex 1.citizen_cat#2.sex 2.citizen_cat#2.sex)

************************************************************************
****** 4. Blinder-Oaxaca Decompositions (Two-Fold, Pooled) *************
************************************************************************

* 1. Clear any existing temporary dummy variables
cap drop dum_eng_* dum_educ_* dum_nchild_* dum_yr_* dum_ind_*

* 2. Generate binary dummy variables (oaxaca does not accept i. syntax)
quietly {
    tab eng_fluency, gen(dum_eng_)
    tab educ_grouped, gen(dum_educ_)
    tab nchild_grouped, gen(dum_nchild_)
    tab year, gen(dum_yr_)
    tab industry_encoded, gen(dum_ind_)
}

* 3. Drop the first dummy in each group as the baseline reference category
drop dum_eng_1 dum_educ_1 dum_nchild_1 dum_yr_1 dum_ind_1

* 4. Controls: same as the regressions except PUMA-state FE (dimensionality),
*    birthplace FE (group-defining for the citizenship contrasts), and the
*    race indicators. Race is deliberately EXCLUDED here. Excluding race keeps
*    race-linked differentials inside the unexplained component.
global oaxaca_controls age_c age_c_sq dum_eng_* dum_educ_* dum_nchild_* dum_yr_* dum_ind_*

* Grouped detail so contributions aggregate by concept
local det detail(GrpAge: age_c age_c_sq, GrpEng: dum_eng_*, GrpEduc: dum_educ_*, GrpKids: dum_nchild_*, GrpYear: dum_yr_*, GrpInd: dum_ind_*)

* Helper: collect each decomposition's components into a postfile so the
* Stata graphs below can be built without re-running the decompositions.
cap program drop post_oaxaca
program define post_oaxaca
    args contrast
    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)
    foreach comp in difference explained unexplained {
        local c = colnumb(`b', "overall:`comp'")
        if `c' < . {
            local bb = `b'[1, `c']
            local ss = sqrt(`V'[`c', `c'])
            post oax ("`contrast'") ("overall") ("`comp'") (`bb') (`ss')
        }
    }
    foreach sec in explained unexplained {
        foreach g in GrpAge GrpEng GrpEduc GrpKids GrpYear GrpInd _cons {
            local c = colnumb(`b', "`sec':`g'")
            if `c' < . {
                local bb = `b'[1, `c']
                local ss = sqrt(`V'[`c', `c'])
                post oax ("`contrast'") ("`sec'") ("`g'") (`bb') (`ss')
            }
        }
    }
end

tempfile oaxtmp
postfile oax str44 contrast str12 section str12 block double b double se using `oaxtmp', replace

* ----------------------------------------------------------------------
* Main decompositions: UNWEIGHTED, pooled two-fold, clustered SEs
* ----------------------------------------------------------------------

* 1. Gender Decomposition (Male vs. Female)
oaxaca ln_wage $oaxaca_controls, by(sex) pooled relax vce(cluster cluster_id) `det'
post_oaxaca "Male vs. Female"
outreg2 using "$tables/oaxaca_results.doc", replace ctitle(Gender Gap) word label

* 2. Citizenship Decomposition (Citizen vs. Non-Citizen)
oaxaca ln_wage $oaxaca_controls, by(non_citizen) pooled relax vce(cluster cluster_id) `det'
post_oaxaca "Citizen vs. Non-Citizen"
outreg2 using "$tables/oaxaca_results.doc", append ctitle(Citizenship Gap) word label

* 3. Intersectional: Non-Citizen Females vs. Citizen Females
oaxaca ln_wage $oaxaca_controls if inlist(citizen_sex, 0, 1), by(citizen_sex) pooled relax vce(cluster cluster_id) `det'
post_oaxaca "NC Female vs. Citizen Female"
outreg2 using "$tables/oaxaca_results.doc", append ctitle(NonCit Female vs Cit Female) word label

* 4. Intersectional: Non-Citizen Females vs. Non-Citizen Males
oaxaca ln_wage $oaxaca_controls if inlist(citizen_sex, 0, 2), by(citizen_sex) pooled relax vce(cluster cluster_id) `det'
post_oaxaca "NC Female vs. NC Male"
outreg2 using "$tables/oaxaca_results.doc", append ctitle(NonCit Female vs NonCit Male) word label

postclose oax

* ----------------------------------------------------------------------
* Blinder-Oaxaca graphs
* ----------------------------------------------------------------------
global figures  "$path/Output/figures"
global paperdir "$path/Paper"
cap mkdir "$figures"

preserve

* Graph 1: forest/dumbbell plot of explained vs. unexplained components
use `oaxtmp', clear
keep if section == "overall" & inlist(block, "explained", "unexplained")
gen ord = 1 if contrast == "Male vs. Female"
replace ord = 2 if contrast == "Citizen vs. Non-Citizen"
replace ord = 3 if contrast == "NC Female vs. Citizen Female"
replace ord = 4 if contrast == "NC Female vs. NC Male"
gen ypos = 5 - ord
drop se
reshape wide b, i(contrast ord ypos) j(block) string

twoway (rspike bexplained bunexplained ypos, horizontal lcolor(gs12) lwidth(medthick)) ///
       (scatter ypos bexplained, mcolor("112 128 144") msymbol(O) msize(medlarge) ///
           mlabel(bexplained) mlabformat(%9.2f) mlabpos(12) mlabsize(vsmall) mlabcolor(gs6)) ///
       (scatter ypos bunexplained, mcolor("33 97 140") msymbol(O) msize(medlarge) ///
           mlabel(bunexplained) mlabformat(%9.2f) mlabpos(12) mlabsize(vsmall) mlabcolor(gs6)), ///
    xline(0, lcolor("231 76 60") lpattern(dash)) ///
    ylabel(4 "Male vs. Female" 3 "Citizen vs. Non-Citizen" ///
           2 "NC Female vs. Citizen Female" 1 "NC Female vs. NC Male", ///
           angle(0) labsize(small) nogrid) ///
    yscale(range(0.5 4.5) noline) ytitle("") ///
    xtitle("Contribution to log wage gap (log points)", size(small)) ///
    legend(order(2 "Explained" 3 "Unexplained") rows(1) pos(6) region(lstyle(none))) ///
    title("Blinder-Oaxaca Decomposition of Wage Gaps", size(medium) color(black)) ///
    subtitle("Two-Fold Pooled Decomposition; SEs Clustered on PUMA-State", size(small) color(gs8)) ///
    graphregion(color(white)) plotregion(color(white))
graph export "$figures/Figure_10_Oaxaca_Summary.png", replace width(2400)
graph export "$paperdir/fig_oaxaca_summary.pdf", replace

* Graph 2: grouped covariate contributions, NC Female vs. NC Male.
use `oaxtmp', clear
keep if contrast == "NC Female vs. NC Male" & inlist(section, "explained", "unexplained")
drop if block == "_cons"
gen blk = ""
replace blk = "Age"       if block == "GrpAge"
replace blk = "English"   if block == "GrpEng"
replace blk = "Education" if block == "GrpEduc"
replace blk = "Children"  if block == "GrpKids"
replace blk = "Year"      if block == "GrpYear"
replace blk = "Industry"  if block == "GrpInd"
gen ord = 1 if blk == "Age"
replace ord = 2 if blk == "English"
replace ord = 3 if blk == "Education"
replace ord = 4 if blk == "Children"
replace ord = 5 if blk == "Year"
replace ord = 6 if blk == "Industry"
drop se block contrast
reshape wide b, i(blk ord) j(section) string

graph hbar bexplained bunexplained, over(blk, sort(ord) label(labsize(small))) ///
    bar(1, color("149 165 166")) bar(2, color("33 97 140")) ///
    blabel(bar, format(%9.2f) size(vsmall) color(gs5)) ///
    legend(order(1 "Explained" 2 "Unexplained") rows(1) pos(6) region(lstyle(none))) ///
    ytitle("Contribution to log wage gap (log points)", size(small)) ///
    yline(0, lcolor("231 76 60") lpattern(dash)) ///
    title("Decomposition Detail: Non-Citizen Female vs. Non-Citizen Male", size(medium) color(black)) ///
    subtitle("Grouped Covariate Contributions to the -0.443 Log-Point Gap", size(small) color(gs8)) ///
    note("Note: baseline unexplained constant = -0.36 log points (omitted from display).", ///
         size(vsmall) color(gs8)) ///
    graphregion(color(white)) plotregion(color(white))
graph export "$figures/Figure_11_Oaxaca_Detail_NCF_NCM.png", replace width(2400)
graph export "$paperdir/fig_oaxaca_detail.pdf", replace

restore

* ----------------------------------------------------------------------
* Robustness: population-weighted decompositions (appendix)
* ----------------------------------------------------------------------

oaxaca ln_wage $oaxaca_controls [pw = perwt], by(sex) pooled relax vce(cluster cluster_id) nodetail
outreg2 using "$tables/oaxaca_weighted.doc", replace ctitle(Gender Gap W) word label

oaxaca ln_wage $oaxaca_controls [pw = perwt], by(non_citizen) pooled relax vce(cluster cluster_id) nodetail
outreg2 using "$tables/oaxaca_weighted.doc", append ctitle(Citizenship Gap W) word label

oaxaca ln_wage $oaxaca_controls [pw = perwt] if inlist(citizen_sex, 0, 1), by(citizen_sex) pooled relax vce(cluster cluster_id) nodetail
outreg2 using "$tables/oaxaca_weighted.doc", append ctitle(NCF vs CF W) word label

oaxaca ln_wage $oaxaca_controls [pw = perwt] if inlist(citizen_sex, 0, 2), by(citizen_sex) pooled relax vce(cluster cluster_id) nodetail
outreg2 using "$tables/oaxaca_weighted.doc", append ctitle(NCF vs NCM W) word label

************************************************************************
****** 5. DATA DIAGNOSTICS & SKEWNESS TESTS ****************************
************************************************************************

* Test for Normality and Skewness of Wages vs. Log Wages
sktest incwage_adj ln_wage

* Summary statistics table with Skewness and Kurtosis for presentation
tabstat incwage_adj ln_wage, stats(mean p50 sd skewness kurtosis n) c(stat)

* Check variance inflation factors (Multicollinearity check)
reg ln_wage i.citizen_cat i.sex $controls
vif

* Residuals vs. fitted values for the preferred Model 3 (heteroskedasticity
* check). 
cap drop resid_m3 fitted_m3
quietly reghdfe ln_wage i.citizen_cat##i.sex $controls, ///
    absorb(year industry_encoded puma_state birthplace) vce(cluster cluster_id) residuals(resid_m3)
gen fitted_m3 = ln_wage - resid_m3
label var resid_m3  "Residuals (Model 3)"
label var fitted_m3 "Fitted log wages (Model 3)"

* Plot a 5% random subsample of points so the PNG stays legible
set seed 381
gen u_plot = runiform()
twoway (scatter resid_m3 fitted_m3 if u_plot < 0.05, ///
        msymbol(oh) msize(vtiny) mcolor("33 97 140%15")), ///
    yline(0, lcolor("231 76 60") lpattern(dash)) ///
    title("Model Diagnostic: Residuals vs. Fitted Log Wages", size(medium) color(black)) ///
    subtitle("Preferred Specification; 5% Random Subsample of Points Shown", size(small) color(gs8)) ///
    xtitle("Fitted log wages", size(small)) ytitle("Residuals", size(small)) ///
    graphregion(color(white)) plotregion(color(white))
graph export "$figures/Figure_12_Residuals_vs_Fitted.png", replace width(2400)
graph export "$paperdir/fig_residuals.pdf", replace
drop u_plot
