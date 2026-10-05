********************************************************************************
/* Step 07: Intersectional Sub-Group Data Bridge (Gender x Education)
   Generates paired ACM matrices for Male/Female x College/NoCollege.
*/
********************************************************************************
clear all
macro drop _all

* --- DEFINE NEW DIRECTORY PATHS ---
global root "/if/research-eme/omar/Gary/mobility_project"
global code "$root/code/build"
global clean_data "$root/data/clean"
global output_path "$root/data/clean/flows_wages_gender_educ" // <--- NEW CSV FOLDER

cd "$code"
do "../initialize.do" "07_prepare_gender_educ_subgroups.do"
use "$clean_data/ipums_asec_panel_classified_granular.dta", clear 

* 1. BASE POPULATION FILTERS & CLEANING
keep if inrange(year, 1978, 2003)
keep if inrange(age, 25, 64)
keep if incwage > 0 & incwage < 9999998
gen ln_w = ln(incwage * cpi99)
gen age2 = age^2
keep if uhrsworkly >= 35 & uhrsworkly < 999 & wkswork1 >= 40

gen black = (race == 200) 
gen hispanic = (hispan > 0 & hispan < 900) 

* 2. DEFINE THE 4 INTERSECTIONAL SUB-GROUPS
local groups "male_nocollege male_college female_nocollege female_college"

local filter_male_nocollege   "sex == 1 & educ_type == 1"
local filter_male_college     "sex == 1 & educ_type == 2"
local filter_female_nocollege "sex == 2 & educ_type == 1"
local filter_female_college   "sex == 2 & educ_type == 2"

* 3. MASTER LOOP
foreach g of local groups {
    di "=================================================="
    di ">>> PROCESSING INTERSECTIONAL GROUP: `g'"
    di "=================================================="
    
    capture matrix drop waget
    capture matrix drop mij_raw
    capture matrix drop b_std
    
    preserve
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
    
    * Interpolate Gaps
    forval s = 1/6 {
        matrix waget[`s', 8]  = (waget[`s', 7] + waget[`s', 9]) / 2
        matrix waget[`s', 18] = (waget[`s', 17] + waget[`s', 19]) / 2
    }
    
    * --- B. TRANSITION MATRIX ---
    collapse (count) n = cpsidp, by(year sector sector_2)
    keep if inrange(sector, 1, 6) & inrange(sector_2, 1, 6)
    reshape wide n, i(year sector) j(sector_2)
    
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
    
    * --- C. EXPORT TO NEW MATRICES DIRECTORY ---
    clear
    svmat mij_raw
    export delimited using "$output_path/mij_raw_`g'.csv", replace nolabel

    clear
    svmat waget
    export delimited using "$output_path/waget_`g'.csv", replace nolabel
    
    restore
}
di ">>> INTERSECTIONAL MATRICES GENERATED SUCCESSFULLY!"
