********************************************************************************
/* Step 05: Data Preparation for ACM (2010) GMM
   Omar Farrag and Gary Lyn
   Last Edited: 04-07-2026
   
   Objectives:
   1. Create Real Wages (Deflated by CPI).
   2. Generate bt (Matrix of Wage Regression Coefficients).
   3. Generate Xbig (The "Standard Worker" covariate matrix).
   4. Generate mij_raw (Year x Origin x Dest transition matrix).
*/
********************************************************************************
clear all
macro drop _all

** Set Script Directory
cd "/if/research-eme/omar/Gary/mobility_project/code/build" /// Linux

do "../initialize.do" "05_preapre_data_for_acm.do"

use "$clean/ipums_asec_panel_classified.dta", clear
*use "$clean/ipums_asec_panel_linked.dta", clear

* 1. POPULATION FILTERS & WAGE CLEANING
* Choose your 26-year block (1978-2003)
keep if inrange(year, 1978, 2003)
keep if sex == 1 & inrange(age, 25, 64)
keep if incwage > 0 & incwage < 9999998
gen ln_w = ln(incwage * cpi99)
gen age2 = age^2
keep if uhrsworkly >= 35 & uhrsworkly < 999 & wkswork1 >= 40

* Define Covariates
gen black = (race == 200) 
gen hispanic = (hispan > 0 & hispan < 900) 
gen educ_somecol = (educ >= 81 & educ <= 92) 
gen educ_col = (educ == 111) 
gen educ_grad = (educ >= 123 & educ <= 125) 

* 2. DEFENSIVE MINCERIAN LOOP
matrix waget = J(6, 26, .)
local year_idx = 1

forval t = 1978/2003 {
    * Check if the year actually has observations after filters
    quietly count if year == `t'
    
    if r(N) == 0 {
        di ">>> WARNING: No observations for year `t'. Skipping regression..."
        * We leave the matrix cells as missing (.) to interpolate after the loop
        forval s = 1/6 {
            matrix waget[`s', `year_idx'] = .
        }
    }
    else {
        di ">>> Processing Year `t'..."
        quietly reg ln_w i.sector age age2 black hispanic educ_somecol educ_col educ_grad if year == `t'
        forval s = 1/6 {
            * Check if specific sector exists in this year
            quietly count if year == `t' & sector == `s'
            if r(N) > 0 {
                quietly margins, at(sector=`s' age=35 age2=1225 black=0 hispanic=0 educ_somecol=0 educ_col=0 educ_grad=0) post
                matrix b_std = e(b)
                matrix waget[`s', `year_idx'] = exp(b_std[1,1])
                * Re-run to reset e() results for next sector
                quietly reg ln_w i.sector age age2 black hispanic educ_somecol educ_col educ_grad if year == `t'
            }
        }
    }
    local year_idx = `year_idx' + 1
}

* 3. INTERPOLATION (Patching the 1985/1995 holes)
* This ensures MATLAB gets a continuous 26-year matrix
forval s = 1/6 {
    * 1985 is column 8 (1978=1, 1984=7, 1985=8)
    matrix waget[`s', 8]  = (waget[`s', 7] + waget[`s', 9]) / 2
    * 1995 is column 18
    matrix waget[`s', 18] = (waget[`s', 17] + waget[`s', 19]) / 2
}

* --- 4. GENERATE FLOW MATRIX (mij_raw) WITH PATCHES ---
preserve
    * Collapse to counts and reshape
    collapse (count) n = cpsidp, by(year sector sector_2)
    
    * We only want the 6 employed sectors for the ACM basic model
    keep if inrange(sector, 1, 6) & inrange(sector_2, 1, 6)
    
    reshape wide n, i(year sector) j(sector_2)
    
    * Patch 1985 and 1995 transition counts
    foreach gap in 1985 1995 {
        local prev = `gap' - 1
        expand 2 if year == `prev', gen(is_patch)
        replace year = `gap' if is_patch == 1
        
        * CRITICAL FIX: Sort by sector then year to allow interpolation
        sort sector year
        
        foreach v of varlist n1-n6 {
            * This looks at the row above (_n-1) and below (_n+1) for the same sector
            quietly by sector: replace `v' = (`v'[_n-1] + `v'[_n+1])/2 if year == `gap'
        }
        drop is_patch
    }
    
    * Final Sort for MATLAB (Year-Major order: all sectors for T, then all for T+1)
    sort year sector
    drop year sector
    mkmat n1-n6, matrix(mij_raw)
restore

* --- 5. UNIVERSAL EXPORT (CSV WORKAROUND) ---
* Export Flow Matrix
preserve
    clear
    svmat mij_raw
    * We drop the first row if it contains variable names (Stata 15 style)
    export delimited using "/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/mij_raw.csv", replace nolabel
restore

* Export Wage Matrix
preserve
    clear
    svmat waget
    export delimited using "/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/waget.csv", replace nolabel
restore

di ">>> DATA EXPORT COMPLETE: mij_raw.csv and waget.csv created."

