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
label variable puma_state "Geographic Identifier (State_PUMA)"

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

label variable incwage_adj  "Wage in Constant 2015 Dollars"
label variable hhincome_adj "HH Income in Constant 2015 Dollars"

* Restrict sample to employed workers with positive wages
keep if empstat == 1 & incwage_adj > 0

* Keep variables
keep year statefip puma puma_state perwt strata cluster serial pernum ///
     sex age age2 citizen_cat educ speakeng nchild incwage_adj rachsing ///
     hhincome_adj birthplace industry_encoded

save "$cleaneddata/clean_data.dta", replace
