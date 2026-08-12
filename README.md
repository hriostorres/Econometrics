# Immigration, Gender, and Citizenship: Intersecting Inequalities in the U.S. Labor Market

This repository contains the full replication package for my econometrics
paper on how citizenship status and sex jointly shape wage disparities in the
U.S. labor market, using a pooled cross-section of the 2012–2019 American
Community Survey.

## Repository structure

| File / folder | Contents |
|---|---|
| `Code/01_Data_Cleaning.do` | Builds the analysis sample from the raw IPUMS extract: 5% single-stage cluster sample of PUMA–state geographies (seed 381), industry/birthplace coding, sample restrictions, CPI adjustment |
| `Code/02_Regressions_and_Stats.do` | Descriptive statistics, the three main regressions (unweighted + `perwt`-weighted), two-fold pooled Oaxaca decompositions with clustered SEs, decomposition and diagnostic graphs |
| `Code/03_Graphs.qmd` | Quarto/R figures: descriptives, GAM returns-to-education, coefficient plot, PUMA coverage map (tigris), model diagnostics; re-estimates the preferred model in `fixest` as a cross-software check |
| `Paper/` | `paper.tex`, `references.bib`, and all figure PDFs used by the manuscript |
| `Output/figures/`, `Output/tables/` | Generated PNG figures and `outreg2` tables |
| `Data/` | Not tracked (see below); contains `raw/`, `interim/`, `clean/` |

## Data

The raw file is an IPUMS USA extract of the 2012–2019 ACS. IPUMS terms of use
**prohibit redistributing extracts**, so no data ship with this repository.
See [`Data/README.md`](Data/README.md) for the exact extract definition needed
to reproduce the analysis.

## How to run

1. Build the IPUMS extract described in [`Data/README.md`](Data/README.md) and
   save it as `Data/raw/IPUMS_data.dta`.
2. Edit the `global path` line at the top of `Code/01_Data_Cleaning.do` and
   `Code/02_Regressions_and_Stats.do` to point at your copy of this repository.
   Those two lines are the only paths that need changing; everything else is
   relative to them.
3. Run, in order:
   - `Code/01_Data_Cleaning.do`
   - `Code/02_Regressions_and_Stats.do`
   - render `Code/03_Graphs.qmd` (the R code resolves paths via `here()` from
     the `.Rproj` at the repository root, so it needs no editing)

## Specification note

The dependent variable is the log of **annual** wage and salary income
(`INCWAGE`, CPI-adjusted to constant 2015 dollars). The sample is restricted to
employed respondents (`EMPSTAT == 1`) aged 16–66 with positive wage income; it
is **not** restricted to full-time or full-year workers, and hours worked is
not currently controlled for. Differences in labor supply between groups
therefore contribute to the estimated gaps and are absorbed into the
*unexplained* component of the Oaxaca decompositions. Addressing this is the
subject of the revision described in `Data/README.md`.
