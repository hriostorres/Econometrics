# Data

This directory is **not tracked by git**. IPUMS USA terms of use prohibit
redistributing extracts, and the raw file (~2.3 GB) exceeds GitHub's 100 MB
per-file limit regardless. Only this README and the `.gitkeep` placeholders
that preserve the folder structure are committed.

```
Data/
├── raw/      IPUMS_data.dta      <- you supply this
├── interim/  sampled_puma_data.dta  (written by 01_Data_Cleaning.do)
└── clean/    clean_data.dta         (written by 01_Data_Cleaning.do)
```

## Building the extract

Register at [usa.ipums.org](https://usa.ipums.org), select the **2012–2019 ACS
1-year samples**, and include the variables below. Download in Stata (`.dta`)
format and save as `Data/raw/IPUMS_data.dta`.

### Variables used by the current code

| Group | Variables |
|---|---|
| Identifiers / weights | `YEAR` `SERIAL` `PERNUM` `PERWT` `STRATA` `CLUSTER` |
| Geography | `STATEFIP` `PUMA` |
| Demographics | `SEX` `AGE` `RACHSING` `NCHILD` |
| Immigration | `CITIZEN` `BPL` |
| Human capital | `EDUC` `SPEAKENG` |
| Labor market | `EMPSTAT` `IND` |
| Income | `INCTOT` `INCWAGE` `HHINCOME` `CPI99` |

Note that `PUMA` is only consistently defined within a PUMA definition era;
2012–2019 falls inside the 2012 PUMA vintage, so `STATEFIP × PUMA` is stable
across all eight years of this panel.

### Additional variables for the hours-adjusted revision

The current specification uses **annual** wage income without conditioning on
hours, so between-group differences in labor supply are being attributed to
the wage. The following variables are needed to separate the price of labor
from the quantity of labor:

| Variable | Purpose |
|---|---|
| `UHRSWORK` | Usual hours worked per week. `00` = N/A (must be dropped, never read as zero); `99` is a **top code** for 99+ hours and is disproportionately male, which biases hourly wages downward for men |
| `WKSWORK2` | Weeks worked last year, intervalled. Needed alongside `UHRSWORK` to build an hourly wage — hours per week alone gives income per weekly-hour, not a wage. **Verify coverage for 2019**: the ACS changed its weeks-worked question that year |
| `MARST` | Marital status. The male marriage premium and female marriage penalty are large and currently omitted |
| `NCHLT5` | Own children under 5. `NCHILD` counts children of any age, which conflates very different labor-supply shocks |
| `CLASSWKRD` | Class of worker. `INCWAGE` excludes self-employment income, so self-employed workers are currently dropped by the `incwage_adj > 0` filter — this makes that exclusion visible and deliberate |
| `EDUCD` | Detailed education. The current 3-category grouping lumps a bachelor's with a doctorate, and the sex composition within that bin is not balanced |
| `GQ` | Group quarters, to restrict to household residents |

`OCC2010` and `YRIMMIG` are **already present** in the existing extract and
simply are not yet used: occupation does considerably more work than the
15-category industry classification in the gender-gap literature, and years
since migration currently pools recent arrivals with long-settled immigrants
in the non-citizen coefficient.

Once hours and weeks are available, the intended sample definitions are:

- **Full-time full-year**, the Blau–Kahn convention: `UHRSWORK >= 35` and
  weeks `>= 50`, for comparability with the published literature.
- **Hourly wage**: `incwage_adj / (uhrswork * weeks)`, keeping `UHRSWORK` as a
  control so the hours differential lands in the *explained* component rather
  than the *unexplained* one. Hourly wages need trimming at both tails, since
  the denominator makes the ratio explode at low hours.

Both belong in the paper: the FTFY restriction and the full-sample hourly
specification answer different questions, and the FTFY filter is itself a
selection rule that drops women at a higher rate than men.
