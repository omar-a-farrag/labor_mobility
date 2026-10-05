********************************************************************************
/* Step 05: Automated Sub-Group Data Bridge
   Generates paired ACM matrices (waget and mij_raw) for 6 distinct groups.
*/
********************************************************************************
clear all
macro drop _all


** Set Script Directory, based on whether we are in Windows or Linux
*cd "Z:/prod-eme/usr/omar/Research/Gary/mobility_project" /// Windows

cd "/if/research-eme/omar/Gary/mobility_project/code/build" /// Linux

do "../initialize.do" "06_preapre_data_for_acm_subgroups.do"
use "$clean/ipums_asec_panel_classified_granular.dta", clear 

* 1. BASE POPULATION FILTERS & CLEANING
keep if inrange(year, 1978, 2003)
keep if inrange(age, 25, 64)
keep if incwage > 0 & incwage < 9999998
gen ln_w = ln(incwage * cpi99)
gen age2 = age^2
keep if uhrsworkly >= 35 & uhrsworkly < 999 & wkswork1 >= 40

* Define Covariates
gen black = (race == 200) 
gen hispanic = (hispan > 0 & hispan < 900) 

* --- APPLY VALUE LABELS TO ORTHOGONAL TYPES ---
/*
label define educ_lbl 1 "No College" 2 "College+"
label values educ_type educ_lbl

label define collar_lbl 1 "White Collar" 2 "Blue Collar"
label values collar_type collar_lbl
*/
* 2. DEFINE THE 6 SUB-GROUPS
local groups "male female nocollege college whitecollar bluecollar"

local filter_male        "sex == 1"
local filter_female      "sex == 2"
local filter_nocollege   "educ_type == 1"
local filter_college     "educ_type == 2"
local filter_whitecollar "collar_type == 1" // <-- Update if your variable is named differently
local filter_bluecollar  "collar_type == 2" // <-- Update if your variable is named differently

* 3. MASTER LOOP: PROCESS AND EXPORT EACH GROUP
foreach g of local groups {
    di "=================================================="
    di ">>> PROCESSING SUB-GROUP: `g'"
    di "=================================================="
    capture matrix drop waget
    capture matrix drop mij_raw
    capture matrix drop b_std
    
    preserve
    
    * Apply specific group filter
    keep if `filter_`g''
    
    * --- A. WAGE MATRIX (waget) ---
    matrix waget = J(6, 26, .)
    local year_idx = 1
    
    forval t = 1978/2003 {
        quietly count if year == `t'
        if r(N) == 0 {
            forval s = 1/6 {
                matrix waget[`s', `year_idx'] = .
            }
        }
        else {
            * Simplified Mincerian to avoid collinearity crashes in subgroups
            quietly reg ln_w i.sector age age2 black hispanic if year == `t'
            forval s = 1/6 {
                quietly count if year == `t' & sector == `s'
                if r(N) > 0 {
                    quietly margins, at(sector=`s' age=35 age2=1225 black=0 hispanic=0) post
                    matrix b_std = e(b)
                    matrix waget[`s', `year_idx'] = exp(b_std[1,1])
                    quietly reg ln_w i.sector age age2 black hispanic if year == `t'
                }
            }
        }
        local year_idx = `year_idx' + 1
    }
    
    * Interpolate 1985 and 1995 Wage Gaps
    forval s = 1/6 {
        matrix waget[`s', 8]  = (waget[`s', 7] + waget[`s', 9]) / 2
        matrix waget[`s', 18] = (waget[`s', 17] + waget[`s', 19]) / 2
    }
    
    * --- B. TRANSITION MATRIX (mij_raw) ---
    collapse (count) n = cpsidp, by(year sector sector_2)
    keep if inrange(sector, 1, 6) & inrange(sector_2, 1, 6)
    reshape wide n, i(year sector) j(sector_2)
    
    * Interpolate 1985 and 1995 Transitions
    foreach gap in 1985 1995 {
        local prev = `gap' - 1
        expand 2 if year == `prev', gen(is_patch)
        replace year = `gap' if is_patch == 1
        sort sector year
        foreach v of varlist n1-n6 {
            quietly by sector: replace `v' = (`v'[_n-1] + `v'[_n+1])/2 if year == `gap'
        }
        drop is_patch
    }
    
    sort year sector
    drop year sector
    mkmat n1-n6, matrix(mij_raw)
    
    * --- C. EXPORT CSVs FOR MATLAB ---
    * Export Flow Matrix
    clear
    svmat mij_raw
    export delimited using "/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/mij_raw_`g'.csv", replace nolabel

    * Recover and Export Wage Matrix
    clear
    svmat waget
    export delimited using "/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/waget_`g'.csv", replace nolabel
    
    restore
}

di ">>> ALL SUB-GROUPS PROCESSED AND EXPORTED SUCCESSFULLY!"
