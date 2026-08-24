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
****** 1. Load Data & Subsample Geographic Units **************
************************************************************************

* Load raw IPUMS data
use "$rawdata/IPUMS_data.dta", clear

* Create unique geographic identifier
gen puma_state = string(statefip) + "_" + string(puma)
label variable puma_state "Geographic Identifier"

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

gen minwage_real = (7.25 * cpi99) * (1 / 0.703)
label variable minwage_real "Federal Minimum Wage (Constant 2015 Dollars)"

************************************************************************
****** 5. Weeks, Hours, and Annual Hours ****************
************************************************************************

gen weeks_worked = .
replace weeks_worked =  7   if wkswork2 == 1   // 1-13 weeks
replace weeks_worked = 20   if wkswork2 == 2   // 14-26 weeks
replace weeks_worked = 33   if wkswork2 == 3   // 27-39 weeks
replace weeks_worked = 43.5 if wkswork2 == 4   // 40-47 weeks
replace weeks_worked = 48.5 if wkswork2 == 5   // 48-49 weeks
replace weeks_worked = 51   if wkswork2 == 6   // 50-52 weeks
* wkswork2 == 0 is n/a (did not work last year) and stays missing.
label variable weeks_worked "Weeks Worked Last Year (interval midpoint)"

* Usual hours per week 
* 0 = n/a (did not work last year).
gen hours_week = uhrswork
replace hours_week = . if uhrswork == 0
label variable hours_week "Usual Hours Worked per Week"

gen byte hours_topcoded = (uhrswork == 99)
label variable hours_topcoded "Usual Hours Top-Coded at 99+"

*  Annual hours 
gen annual_hours = hours_week * weeks_worked
label variable annual_hours "Annual Hours Worked (hours/week x weeks)"

*  Full-time full-year indicator :
// The Blau-Kahn convention: >= 35 usual hours/week and >= 50 weeks/year
gen byte ftfy = (hours_week >= 35 & wkswork2 == 6) if !missing(hours_week, weeks_worked)
label variable ftfy "Full-Time Full-Year Worker (35+ hrs, 50+ wks)"

label define ftfy_lbl 0 "Not FTFY" 1 "FTFY"
label values ftfy ftfy_lbl

* Part-time indicator
gen byte part_time = (hours_week < 35) if !missing(hours_week)
label variable part_time "Usually Works Part-Time (<35 hrs/week)"

************************************************************************
****** 6. Marital Status and Presence of Young Children ***************
************************************************************************

gen byte marital_status = .
replace marital_status = 1 if inlist(marst, 1, 2)     // married (present or absent)
replace marital_status = 2 if inlist(marst, 3, 4, 5)  // separated/divorced/widowed
replace marital_status = 3 if marst == 6              // never married

label define marital_lbl 1 "Married" 2 "Previously Married" 3 "Never Married"
label values marital_status marital_lbl
label variable marital_status "Marital Status Group"

gen byte married = (marital_status == 1) if !missing(marital_status)
label variable married "Currently Married"

* young children in the HH
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

gen hourly_wage = incwage_adj / annual_hours
label variable hourly_wage "Hourly Wage (Constant 2015 Dollars)"

gen byte wage_implausible = 0
replace wage_implausible = 1 if hourly_wage < (0.5 * minwage_real) & !missing(hourly_wage)
replace wage_implausible = 1 if hourly_wage > 200               & !missing(hourly_wage)
label variable wage_implausible "Hourly Wage Outside Plausible Range"

************************************************************************
****** 8. Analysis Sample Restriction *********************************
************************************************************************

count
drop if missing(incwage_adj) | incwage_adj <= 0
drop if empstat != 1
drop if wage_implausible == 1
count

assert !missing(annual_hours) & annual_hours > 0


compress

capture order year statefip puma puma_state perwt strata cluster serial pernum ///
      sex age age2 citizen_cat birthplace educ speakeng rachsing ///
      marital_status married nchild nchlt5_grouped has_child_lt5 ///
      incwage_adj hourly_wage hours_week weeks_worked annual_hours ///
      ftfy part_time hours_topcoded industry_encoded

save "$cleaneddata/clean_data.dta", replace

describe, short
