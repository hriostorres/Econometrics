This repository contains the full replication package for my econometrics revisited
paper: ``To what extent are gender and citizenship wage disparities driven by differences in labor supply, human capital, and returns to observed characteristics?'' using 2012–2019 ACS data.

## Repository structure

| File / folder | Contents |
|---|---|
| `Code/01_Data_Cleaning.do` | Builds the analysis sample from the raw IPUMS extract |
| `Code/02_Regressions_and_Stats.do` | Descriptive statistics, main regressions, two-fold pooled Oaxaca decompositions with clustered SEs, decomposition and diagnostic graphs |
| `Code/03_Graphs.qmd` | Quarto/R figures|
| `Paper/` | `paper.tex`, `references.bib`, and all figure PDFs used by the manuscript |
| `Output/figures/`, `Output/tables/` | Generated PNG figures and `outreg2` tables |
| `Data/` | Not tracked; contains `raw/`, `interim/`, `clean/` |

## Data

The raw file is an IPUMS USA extract of the 2012–2019 ACS. IPUMS terms of use
**prohibit redistributing extracts**, so no data ship with this repository.
See [`Data/README.md`](Data/README.md) for the exact extract definition needed
to reproduce the analysis.
