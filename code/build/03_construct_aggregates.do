********************************************************************************
/* Step 03: Construct Sector & Demographic Aggregates (Unified)
   Omar Farrag and Gary Lyn
   Created: 03-26-2026
   Last Edited: 03-26-2026
   
   Updates: 
   - Consolidates Macro and Granular aggregations into a single script.
   - Outputs both gross_flows_matrix_macro.dta and _granular.dta
*/
********************************************************************************
clear all
macro drop _all
cd "/if/research-eme/omar/Gary/mobility_project/code/build" 
do "../initialize.do" "03_construct_aggregates"

di ">>> Starting Step 3: Unified Macro & Granular Aggregation"

use "$clean/ipums_asec_panel_linked.dta", clear

* --- 1. DEFINE ORTHOGONAL WORKER TYPES ---
gen educ_type = .
replace educ_type = 1 if inrange(educ, 2, 73)   
replace educ_type = 2 if inrange(educ, 80, 125) 
drop if educ == 999 | educ == 0 | educ == .     

gen collar_type = .
replace collar_type = 1 if inrange(occ1990, 0, 400) 
replace collar_type = 2 if inrange(occ1990, 405, 900)
drop if collar_type == . 

* --- 2. DEFINE THE SECTORS ---
foreach yr in "" "_2" {
    gen sector`yr' = 7 
    tempvar is_employed`yr'
    gen `is_employed`yr'' = (empstat`yr' == 10 | empstat`yr' == 12)
    
    replace sector`yr' = 5 if inrange(ind1990`yr', 0, 939) & `is_employed`yr'' == 1
    replace sector`yr' = 1 if inrange(ind1990`yr', 10, 50) & `is_employed`yr'' == 1
    replace sector`yr' = 2 if ind1990`yr' == 60 & `is_employed`yr'' == 1
    replace sector`yr' = 3 if inrange(ind1990`yr', 100, 392) & `is_employed`yr'' == 1
    replace sector`yr' = 4 if inrange(ind1990`yr', 500, 691) & `is_employed`yr'' == 1
    replace sector`yr' = 6 if inrange(ind1990`yr', 400, 472) & `is_employed`yr'' == 1
}

label define sec_lbl 1 "Agric/Min" 2 "Construction" 3 "Manufacturing" 4 "Trade" 5 "Services" 6 "Trans/Util" 7 "Non-Employed"
label values sector sec_lbl
label values sector_2 sec_lbl

* Save the unified classified microdata
save "$clean/ipums_asec_panel_classified.dta", replace

* --- 3. COLLAPSE MATRICES ---
rename sector origin_j
rename sector_2 dest_k

* PATH A: Granular Matrix
preserve
    di ">>> Collapsing Granular Matrix..."
    collapse (sum) gross_flow = asecwth, by(year educ_type collar_type origin_j dest_k)
    order year educ_type collar_type origin_j dest_k gross_flow
    sort year educ_type collar_type origin_j dest_k
    compress
    save "$clean/gross_flows_matrix_granular.dta", replace
restore

* PATH B: Pure Macro Matrix
preserve
    di ">>> Collapsing Macro Matrix..."
    collapse (sum) gross_flow = asecwth, by(year origin_j dest_k)
    order year origin_j dest_k gross_flow
    sort year origin_j dest_k
    compress
    save "$clean/gross_flows_matrix_macro.dta", replace
restore

di ">>> Step 3 Complete. Both matrices saved."
