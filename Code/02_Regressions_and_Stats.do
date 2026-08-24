/*
Do File: Part 2 - Descriptive Statistics, Regressions & Oaxaca Decomposition
by Hermogenes David
*/

clear all
set more off

global path        "/Users/davidrios/Econometrics_Final_Paper"
global cleaneddata "$path/Data/clean"
global tables      "$path/Output/tables"
global figures     "$path/Output/figures"
global paperdir    "$path/Paper"

cap mkdir "$path/Output"
cap mkdir "$tables"
cap mkdir "$figures"

use "$cleaneddata/clean_data.dta", clear

capture drop ln_wage ln_wage_hr ln_hours cluster_id age_c age_c_sq
capture drop educ_grouped eng_fluency nchild_grouped non_citizen citizen_sex
capture drop resid_m6 fitted_m6 u_plot educ_years
capture drop dum_*
capture drop _est_*

capture label drop educgrp englbl nchildgrp citizen_sex_lbl

assert !missing(incwage_adj) & incwage_adj > 0
assert !missing(annual_hours) & annual_hours > 0

****** 1. Variable Transformation & Recoding ***************************

gen ln_wage    = log(incwage_adj)
gen ln_wage_hr = log(hourly_wage)
gen ln_hours   = log(annual_hours)
label var ln_wage    "Log Annual Wage (2015$)"
label var ln_wage_hr "Log Hourly Wage (2015$)"
label var ln_hours   "Log Annual Hours"

egen cluster_id = group(puma_state)
label var cluster_id "PUMA-State Cluster ID"

* Center age at the unweighted sample mean
sum age, meanonly
gen age_c    = age - r(mean)
gen age_c_sq = age_c^2
label var age_c    "Age (centered at mean)"
label var age_c_sq "Age Squared (centered at mean)"

* else = . keeps unlisted codes (e.g. speakeng 0 = N/A) missing, not copied
recode educ (0/6 = 1 "HS or Less") (7/9 = 2 "Some College") ///
            (10/11 = 3 "Bachelor's or Higher") (else = .), ///
            gen(educ_grouped) label(educgrp)

recode speakeng (3 4 = 1 "Fluent") (2 5 = 2 "Intermediate") ///
                (1 6 = 3 "Limited") (else = .), ///
                gen(eng_fluency) label(englbl)

recode nchild (0 = 0 "None") (1 = 1 "One") (2 = 2 "Two") ///
              (3/4 = 3 "Three-Four") (5/9 = 4 "Five+") (else = .), ///
              gen(nchild_grouped) label(nchildgrp)

label var educ_grouped   "Educational Attainment Group"
label var eng_fluency    "English Fluency Group"
label var nchild_grouped "Number of Children Group"

gen byte non_citizen = (citizen_cat == 2)
label var non_citizen "Non-Citizen Indicator"

* 2*(male) + (citizen): 0=NC Female, 1=Cit Female, 2=NC Male, 3=Cit Male
gen byte citizen_sex = 2 * (sex == 1) + (citizen_cat != 2)
label define citizen_sex_lbl 0 "Non-Citizen Female" 1 "Citizen Female" ///
                             2 "Non-Citizen Male"   3 "Citizen Male", replace
label values citizen_sex citizen_sex_lbl

****** 1b. Specification Globals ***************************************

* hhincome_adj excluded (bad control). Race sits alongside birthplace FE.
global controls  age_c age_c_sq i.educ_grouped i.eng_fluency i.nchild_grouped i.rachsing

* Marital status interacted with sex
global controls2 $controls i.marital_status##i.sex i.nchlt5_grouped
global hrs       ln_hours
global fe        absorb(year industry_encoded puma_state birthplace)
global core      keep(1.citizen_cat 2.citizen_cat 2.sex 1.citizen_cat#2.sex 2.citizen_cat#2.sex)

****** 2. Descriptive Statistics (Appendix Tables) *********************

tab citizen_cat
tab sex
tab citizen_cat sex, sum(incwage_adj) means
table citizen_cat sex, statistic(median incwage_adj)

* ---------------------------------------------------------------------
* Table 1: composition, mean AND median annual wage income
* ---------------------------------------------------------------------

quietly count
local Ntot = r(N)

local t1lab `" "Native citizen" "Naturalized citizen" "Non-citizen" "Male" "Female" "'
local t1con `" "citizen_cat==0" "citizen_cat==1" "citizen_cat==2" "sex==1" "sex==2" "'

capture file close t1
file open t1 using "$tables/table1_descriptives.txt", write replace
file write t1 "| Group | N | Share | Mean wage | Median wage |" _n
file write t1 "|:------|-----:|------:|----------:|------------:|" _n

display _newline "--- Table 1: sample composition and annual wage income ---"
forvalues j = 1/5 {
    local lab : word `j' of `t1lab'
    local con : word `j' of `t1con'
    quietly summarize incwage_adj if `con', detail
    local n  = r(N)
    local mn = r(mean)
    local md = r(p50)
    local sh = 100 * `n' / `Ntot'
    display "`lab'" _col(24) %10.0fc `n' %9.2f `sh' "%" %12.0fc `mn' %12.0fc `md'
    file write t1 "| `lab' | " %10.0fc (`n') " | " %5.2f (`sh') "% | " ///
        %10.0fc (`mn') " | " %10.0fc (`md') " |" _n
}
file close t1

* ---------------------------------------------------------------------
* Table 2: labor supply margins by group
* ---------------------------------------------------------------------
local t2lab `" "Male" "Female" "Native female" "Naturalized female" "Non-citizen female" "Non-citizen male" "'
local t2con `" "sex==1" "sex==2" "sex==2 & citizen_cat==0" "sex==2 & citizen_cat==1" "sex==2 & citizen_cat==2" "sex==1 & citizen_cat==2" "'

capture file close t2
file open t2 using "$tables/table2_labor_supply.txt", write replace
file write t2 "| Group | Mean annual hours | Median annual hours | FTFY share |" _n
file write t2 "|:------|------------------:|--------------------:|-----------:|" _n

display _newline "--- Table 2: annual hours and FTFY status ---"
forvalues j = 1/6 {
    local lab : word `j' of `t2lab'
    local con : word `j' of `t2con'
    quietly summarize annual_hours if `con', detail
    local mh = r(mean)
    local dh = r(p50)
    quietly summarize ftfy if `con'
    local fs = 100 * r(mean)
    display "`lab'" _col(24) %10.0fc `mh' %10.0fc `dh' %9.1f `fs' "%"
    file write t2 "| `lab' | " %10.0fc (`mh') " | " %10.0fc (`dh') " | " %5.1f (`fs') "% |" _n
}
file close t2

type "$tables/table1_descriptives.txt"
type "$tables/table2_labor_supply.txt"

* Labor supply by sex: the margin the unadjusted model confounds
table sex, statistic(mean annual_hours) statistic(median annual_hours) ///
           statistic(mean ftfy) statistic(mean part_time)
table citizen_cat sex, statistic(mean annual_hours) statistic(mean ftfy)

* Mean log hours: the exact hours gap, not the log-of-means approximation
table sex, statistic(mean ln_wage) statistic(mean ln_hours) statistic(mean ln_wage_hr)

tab marital_status sex, col
tab nchlt5_grouped sex, col
tab industry_encoded if citizen_cat == 2

****** 2b. Figures Quoted in the Paper Text ****************************

capture drop educ_years
gen educ_years = .
replace educ_years = 0  if educ == 0
replace educ_years = 2  if educ == 1
replace educ_years = 6  if educ == 2
replace educ_years = 9  if educ == 3
replace educ_years = 10 if educ == 4
replace educ_years = 11 if educ == 5
replace educ_years = 12 if educ == 6
replace educ_years = 13 if educ == 7
replace educ_years = 14 if educ == 8
replace educ_years = 15 if educ == 9
replace educ_years = 16 if educ == 10
replace educ_years = 18 if educ == 11
label var educ_years "Years of Formal Education (imputed midpoints)"

display _newline "=== Numbers quoted in the paper text ==="

* Non-citizen gender gap in levels
quietly summarize incwage_adj if citizen_cat == 2 & sex == 2
local ncf = r(mean)
quietly summarize incwage_adj if citizen_cat == 2 & sex == 1
local ncm = r(mean)
display "NC female mean wage  = " %9.0fc `ncf'
display "NC male mean wage    = " %9.0fc `ncm'
display "NC female / NC male  = " %5.1f 100 * `ncf' / `ncm' "%"

* Labor supply margins
quietly summarize ftfy if sex == 2
display "Women NOT full-time full-year = " %5.1f 100 * (1 - r(mean)) "%"
quietly summarize ftfy if sex == 1
display "Men   NOT full-time full-year = " %5.1f 100 * (1 - r(mean)) "%"

quietly summarize annual_hours if sex == 1
local hm = r(mean)
quietly summarize annual_hours if sex == 2
display "Mean annual hours gap (M - F) = " %6.0f `hm' - r(mean)

* Skewness before and after the log transformation
quietly summarize incwage_adj, detail
display "Skewness, raw wage = " %6.2f r(skewness)
quietly summarize ln_wage, detail
display "Skewness, log wage = " %6.2f r(skewness)

* Top-coded usual hours
quietly summarize hours_topcoded
display "Top-coded hours, all    = " %5.2f 100 * r(mean) "%"
quietly summarize hours_topcoded if sex == 1
display "Top-coded hours, men    = " %5.2f 100 * r(mean) "%"
quietly summarize hours_topcoded if sex == 2
display "Top-coded hours, women  = " %5.2f 100 * r(mean) "%"

* Industry composition of the non-citizen workforce (paper quotes the top five)
display _newline "--- Industry shares among non-citizens ---"
tab industry_encoded if citizen_cat == 2, sort

* ---------------------------------------------------------------------
* Returns to education, revisited
* ---------------------------------------------------------------------

display _newline "--- Share with fewer than 12 years of schooling (age 25+) ---"
forvalues k = 0/3 {
    local lbl : label citizen_sex_lbl `k'
    quietly count if citizen_sex == `k' & !missing(educ_years) & age >= 25
    local den = r(N)
    quietly count if citizen_sex == `k' & educ_years < 12 & age >= 25
    display "`lbl'" _col(24) "less than 12 yrs: " %5.1f 100 * r(N) / `den' "%"
}

display _newline "--- Returns per year of schooling, below vs. above 12 years ---"
capture file close re
file open re using "$tables/returns_to_education.txt", write replace
file write re "| Group | Slope, <12 years | Slope, 12+ years | N (<12) | N (12+) |" _n
file write re "|:------|-----------------:|-----------------:|--------:|--------:|" _n

forvalues k = 0/3 {
    local lbl : label citizen_sex_lbl `k'
    foreach seg in below above {
        if "`seg'" == "below" local cond "educ_years < 12"
        else                  local cond "educ_years >= 12"
        quietly reg ln_wage educ_years if citizen_sex == `k' & `cond' & age >= 25, ///
            vce(cluster cluster_id)
        local b_`seg'  = _b[educ_years]
        local se_`seg' = _se[educ_years]
        local n_`seg'  = e(N)
        display "`seg'" _col(8) "`lbl'" _col(30) "slope = " %7.4f _b[educ_years] ///
            "  se = " %6.4f _se[educ_years] "  N = " %9.0fc e(N)
    }
    file write re "| `lbl' | " %7.3f (`b_below') " (" %5.3f (`se_below') ") | " ///
        %7.3f (`b_above') " (" %5.3f (`se_above') ") | " ///
        %9.0fc (`n_below') " | " %9.0fc (`n_above') " |" _n
}
file close re
type "$tables/returns_to_education.txt"

* Formal test: do non-citizens receive different returns above high school?

display _newline "--- Non-citizen x education interaction, above 12 years ---"
reghdfe ln_wage c.educ_years##i.non_citizen age_c age_c_sq i.eng_fluency ///
    i.nchild_grouped i.rachsing i.marital_status##i.sex i.nchlt5_grouped ///
    ln_hours if educ_years >= 12 & age >= 25, ///
    absorb(year industry_encoded puma_state birthplace) vce(cluster cluster_id)
lincom c.educ_years + 1.non_citizen#c.educ_years

****** 3. Regression Specifications ************************************

* M1 unadjusted | M2 + human capital | M3 + marital x sex, kids<5 | M4 + hours
* M5 full FE (PREFERRED) | M6 full FE + hours (PREFERRED, adjusted)
local rhs1 ""
local rhs2 "$controls"
local rhs3 "$controls2"
local rhs4 "$controls2 $hrs"

foreach wt in unw w {

    if "`wt'" == "unw" local wvar ""
    else               local wvar "[pw = perwt]"

    forvalues k = 1/4 {
        reg ln_wage i.citizen_cat##i.sex `rhs`k'' `wvar', vce(cluster cluster_id)
        estimates store m`k'_`wt'
    }

    reghdfe ln_wage i.citizen_cat##i.sex $controls2 `wvar', $fe vce(cluster cluster_id)
    estimates store m5_`wt'

    reghdfe ln_wage i.citizen_cat##i.sex $controls2 $hrs `wvar', $fe vce(cluster cluster_id)
    estimates store m6_`wt'
}

* Writes one outreg2 table: first model replaces and carries the title
cap program drop mktable
program define mktable
    args file ttl mods cts full
    local i 0
    foreach m of local mods {
        local ++i
        local ct : word `i' of `cts'
        local opt = cond(`i' == 1, "replace", "append")
        local t ""
        if `i' == 1 local t title("`ttl'")
        local k "$core"
        if "`full'" == "full" local k ""
        outreg2 [`m'] using "$tables/`file'", `opt' ctitle("`ct'") `t' ///
            dec(3) se label word `k'
    }
end

mktable "wage_regressions_main.doc" "Log Annual Wage: Gender and Citizenship" ///
    "m1_unw m2_unw m3_unw m4_unw m5_unw m6_unw" ///
    `" "M1 Unadjusted" "M2 + human capital" "M3 + marital, kids<5" "M4 + hours" "M5 full FE" "M6 full FE + hours" "'

mktable "hours_adjustment.doc" "Preferred Specification: Effect of Adjusting for Hours" ///
    "m5_unw m6_unw" `" "Without hours" "With hours" "'

mktable "wage_regressions_full.doc" "Full Coefficient Estimates" ///
    "m5_unw m6_unw" `" "M5" "M6" "' "full"

mktable "weighted_robustness.doc" "Unweighted vs Population-Weighted (ACS perwt)" ///
    "m5_unw m5_w m6_unw m6_w" ///
    `" "M5 unweighted" "M5 weighted" "M6 unweighted" "M6 weighted" "'

	
* M6 equals an hourly-wage regression. Above 1 implies increasing returns.
quietly reghdfe ln_wage i.citizen_cat##i.sex $controls2 $hrs, $fe vce(cluster cluster_id)
display _newline "Test: hours elasticity = 1"
test ln_hours = 1

****** 3b. Sensitivity *************************************************

reghdfe ln_wage_hr i.citizen_cat##i.sex $controls2, $fe vce(cluster cluster_id)
estimates store s_hourly

reghdfe ln_wage i.citizen_cat##i.sex $controls2 if ftfy == 1, $fe vce(cluster cluster_id)
estimates store s_ftfy

reghdfe ln_wage i.citizen_cat##i.sex $controls2 ln_hours i.ftfy i.part_time, ///
    $fe vce(cluster cluster_id)
estimates store s_hrsrich

reghdfe ln_wage i.citizen_cat##i.sex $controls2 $hrs if hours_topcoded == 0, ///
    $fe vce(cluster cluster_id)
estimates store s_notc

mktable "sensitivity.doc" "Sensitivity Analyses" ///
    "s_hourly s_ftfy s_hrsrich s_notc" ///
    `" "Hourly DV" "FTFY subsample" "Rich hours controls" "No topcoded hours" "'

****** 4. Blinder-Oaxaca Decompositions (Two-Fold, Pooled) *************

cap drop dum_*

* oaxaca does not accept i. syntax
quietly {
    tab eng_fluency,      gen(dum_eng_)
    tab educ_grouped,     gen(dum_educ_)
    tab nchild_grouped,   gen(dum_nchild_)
    tab year,             gen(dum_yr_)
    tab industry_encoded, gen(dum_ind_)
    tab marital_status,   gen(dum_mar_)
    tab nchlt5_grouped,   gen(dum_k5_)
}

* First dummy in each group is the omitted reference category
drop dum_eng_1 dum_educ_1 dum_nchild_1 dum_yr_1 dum_ind_1 dum_mar_1 dum_k5_1

* Excludes PUMA-state FE, birthplace FE, and race.
global oax_nohrs age_c age_c_sq dum_eng_* dum_educ_* dum_nchild_* dum_k5_* ///
                 dum_mar_* dum_yr_* dum_ind_*
global oax_hrs   $oax_nohrs ln_hours

local dbase GrpAge: age_c age_c_sq, GrpEng: dum_eng_*, GrpEduc: dum_educ_*, GrpKids: dum_nchild_*, GrpKids5: dum_k5_*, GrpMar: dum_mar_*, GrpYear: dum_yr_*, GrpInd: dum_ind_*
local det_nohrs detail(`dbase')
local det_hrs   detail(`dbase', GrpHours: ln_hours)

* The four contrasts, reused by the decompositions and both graph blocks
local cnames `" "Male vs. Female" "Citizen vs. Non-Citizen" "NC Female vs. Citizen Female" "NC Female vs. NC Male" "'
local cshort  Gender Citizenship NCFvsCF NCFvsNCM
local cby     sex non_citizen citizen_sex citizen_sex
local cif    `" "" "" "if inlist(citizen_sex, 0, 1)" "if inlist(citizen_sex, 0, 2)" "'

cap program drop post_oaxaca
program define post_oaxaca
    args spec contrast
    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)
    foreach comp in difference explained unexplained {
        local c = colnumb(`b', "overall:`comp'")
        if `c' < . {
            post oax ("`spec'") ("`contrast'") ("overall") ("`comp'") ///
                     (`b'[1, `c']) (sqrt(`V'[`c', `c']))
        }
    }
    foreach sec in explained unexplained {
        foreach g in GrpAge GrpEng GrpEduc GrpKids GrpKids5 GrpMar GrpYear GrpInd GrpHours _cons {
            local c = colnumb(`b', "`sec':`g'")
            if `c' < . {
                post oax ("`spec'") ("`contrast'") ("`sec'") ("`g'") ///
                         (`b'[1, `c']) (sqrt(`V'[`c', `c']))
            }
        }
    }
end

tempfile oaxtmp
postfile oax str8 spec str44 contrast str12 section str12 block double b double se ///
    using `oaxtmp', replace

* Every contrast twice: without hours, then with. 

local n 0
foreach s in nohrs hrs {
    forvalues j = 1/4 {
        local nm : word `j' of `cnames'
        local sh : word `j' of `cshort'
        local by : word `j' of `cby'
        local cd : word `j' of `cif'
        local ++n
        local opt = cond(`n' == 1, "replace", "append")

        oaxaca ln_wage ${oax_`s'} `cd', by(`by') pooled relax ///
            vce(cluster cluster_id) `det_`s''
        post_oaxaca "`s'" "`nm'"
        outreg2 using "$tables/oaxaca_results.doc", `opt' ctitle(`sh' `s') word label
    }
}
postclose oax

* Weighted decompositions, hours spec only
local n 0
forvalues j = 1/4 {
    local sh : word `j' of `cshort'
    local by : word `j' of `cby'
    local cd : word `j' of `cif'
    local ++n
    local opt = cond(`n' == 1, "replace", "append")

    oaxaca ln_wage $oax_hrs [pw = perwt] `cd', by(`by') pooled relax ///
        vce(cluster cluster_id) nodetail
    outreg2 using "$tables/oaxaca_weighted.doc", `opt' ctitle(`sh' W) word label
}

* ----------------------------------------------------------------------
* Blinder-Oaxaca graphs
* ----------------------------------------------------------------------

preserve

* Graph 1: explained vs unexplained, one figure per spec
foreach s in nohrs hrs {

    if "`s'" == "nohrs" local slab "Without hours control"
    else                local slab "With hours control"

    use `oaxtmp', clear
    keep if spec == "`s'" & section == "overall" & inlist(block, "explained", "unexplained")
    gen ord = .
    forvalues j = 1/4 {
        local nm : word `j' of `cnames'
        replace ord = `j' if contrast == "`nm'"
    }
    drop se spec
    reshape wide b, i(contrast ord) j(block) string

    * Stacked: segments sum to the total gap, so bar length = the gap
    graph hbar (asis) bexplained bunexplained, ///
        over(contrast, sort(ord) label(labsize(vsmall))) stack ///
        bar(1, color("149 165 166")) bar(2, color("33 97 140")) ///
        blabel(bar, format(%9.2f) size(vsmall) color(white) position(inside)) ///
        legend(order(1 "Explained" 2 "Unexplained") rows(1) pos(6) region(lstyle(none))) ///
        ytitle("Contribution to log wage gap (log points)", size(small)) ///
        yline(0, lcolor("231 76 60") lpattern(dash)) ///
        title("Blinder-Oaxaca Decomposition of Wage Gaps", size(medium) color(black)) ///
        subtitle("`slab'; Two-Fold Pooled, SEs Clustered on PUMA-State", size(small) color(gs8)) ///
        graphregion(color(white)) plotregion(color(white))
    graph export "$figures/Figure_10_Oaxaca_Summary_`s'.png", replace width(2400)
    graph export "$paperdir/fig_oaxaca_summary_`s'.pdf", replace
}

* Graph 2: grouped covariate contributions, gender gap, hours controlled
use `oaxtmp', clear
keep if spec == "hrs" & contrast == "Male vs. Female" & inlist(section, "explained", "unexplained")
drop if block == "_cons"

local blocks GrpAge GrpEng GrpEduc GrpKids GrpKids5 GrpMar GrpYear GrpInd GrpHours
local blabs `" "Age" "English" "Education" "Children" "Children <5" "Marital" "Year" "Industry" "Hours" "'
gen blk = ""
gen ord = .
local j 0
foreach b of local blocks {
    local ++j
    local l : word `j' of `blabs'
    replace blk = "`l'" if block == "`b'"
    replace ord = `j'   if block == "`b'"
}
drop se block contrast spec
reshape wide b, i(blk ord) j(section) string

graph hbar bexplained bunexplained, over(blk, sort(ord) label(labsize(small))) ///
    bar(1, color("149 165 166")) bar(2, color("33 97 140")) ///
    blabel(bar, format(%9.2f) size(vsmall) color(gs5)) ///
    legend(order(1 "Explained" 2 "Unexplained") rows(1) pos(6) region(lstyle(none))) ///
    ytitle("Contribution to log wage gap (log points)", size(small)) ///
    yline(0, lcolor("231 76 60") lpattern(dash)) ///
    title("Decomposition Detail: Gender Gap", size(medium) color(black)) ///
    subtitle("Grouped Covariate Contributions, Hours Controlled", size(small) color(gs8)) ///
    graphregion(color(white)) plotregion(color(white))
graph export "$figures/Figure_11_Oaxaca_Detail_Gender.png", replace width(2400)
graph export "$paperdir/fig_oaxaca_detail.pdf", replace

restore

****** 5. DIAGNOSTICS **************************************************

tabstat incwage_adj ln_wage annual_hours ln_hours, ///
    stats(mean p50 sd skewness kurtosis n) c(stat)

reg ln_wage i.citizen_cat i.sex $controls2 $hrs
vif

cap drop resid_m6 fitted_m6
quietly reghdfe ln_wage i.citizen_cat##i.sex $controls2 $hrs, ///
    $fe vce(cluster cluster_id) residuals(resid_m6)
gen fitted_m6 = ln_wage - resid_m6
label var resid_m6  "Residuals (M6)"
label var fitted_m6 "Fitted log annual wages (M6)"

* 5% random subsample so the PNG stays legible
set seed 381
gen u_plot = runiform()
twoway (scatter resid_m6 fitted_m6 if u_plot < 0.5, ///
        msymbol(oh) msize(vtiny) mcolor("33 97 140%15")), ///
    yline(0, lcolor("231 76 60") lpattern(dash)) ///
    title("Model Diagnostic: Residuals vs. Fitted Log Annual Wages", size(medium) color(black)) ///
    subtitle("Preferred Specification (M6); 50% Random Subsample Shown", size(small) color(gs8)) ///
    xtitle("Fitted log annual wages", size(small)) ytitle("Residuals", size(small)) ///
    graphregion(color(white)) plotregion(color(white))
graph export "$figures/Figure_12_Residuals_vs_Fitted.png", replace width(2400)
graph export "$paperdir/fig_residuals.pdf", replace
drop u_plot
