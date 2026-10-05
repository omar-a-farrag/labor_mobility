********************************************************************************
/* Step 04: Prepare Variables (Unified)
   Omar Farrag and Gary Lyn
   Created: 03-26-2026
   Last Edited: 03-26-2026
   
   Updates: 
   - Loops over both "macro" and "granular" specifications.
   - Outputs cdp_estimation_data_macro.dta and _granular.dta
*/
********************************************************************************
clear all
macro drop _all
cd "/if/research-eme/omar/Gary/mobility_project/code/build" 
do "../initialize.do" "04_prep_cdp_variables"

di ">>> Starting Step 4: Unified Variable Preparation"

* Loop through both datasets
foreach ds in "macro" "granular" {
    
    di "=========================================================="
    di ">>> PROCESSING DATASET: `ds'"
    di "=========================================================="
    
    * Set demographic grouping variables dynamically
    if "`ds'" == "macro" {
        local demog ""
    }
    else {
        local demog "educ_type collar_type"
    }


    * --- 1. EXTRACT REAL ANNUAL SECTOR WAGES ---
	use "$clean/ipums_asec_panel_classified.dta", clear
	capture drop __*

	* Clean incwage (IPUMS codes missing/NIU as 9999998+)
	keep if incwage > 0 & incwage < 9999998

	* Use the new IPUMS CPI variable to create real wages in 1999 dollars
	gen real_wage = incwage * cpi99
	gen ln_w = ln(real_wage)

	* Optional: Use uhrsworkly to ensure we are looking at full-time workers 
	* (matches the 'Standard Worker' logic)
	keep if uhrsworkly >= 35 & wkswork1 >= 40

	* Collapse to mean wages by year, sector, and demographic group
	collapse (mean) w_k = ln_w [pw=asecwt], by(year `demog' sector)
	rename sector dest_k
	tempfile w_k_data
	save `w_k_data'


    * --- 2. CALCULATE TRANSITION PROBABILITIES (mu) ---
    use "$clean/gross_flows_matrix_`ds'.dta", clear

    bysort year `demog' origin_j: egen total_flow_j = sum(gross_flow)
    gen mu_jk = gross_flow / total_flow_j

    preserve
        keep if origin_j == dest_k
        keep year `demog' origin_j mu_jk
        rename mu_jk mu_jj
        tempfile stayers_j
        save `stayers_j'
    restore
    merge m:1 year `demog' origin_j using `stayers_j', keep(master match) nogenerate

    preserve
        use `stayers_j', clear
        rename origin_j dest_k
        rename mu_jj mu_kk
        tempfile stayers_k
        save `stayers_k'
    restore
    merge m:1 year `demog' dest_k using `stayers_k', keep(master match) nogenerate


    * --- 3. ASSEMBLE THE PANEL & CREATE T+1 LEADS ---
    merge m:1 year `demog' dest_k using `w_k_data', keep(master match) nogenerate

    egen route_id = group(`demog' origin_j dest_k)
    xtset route_id year

    gen w_k_F1   = F.w_k       
    gen mu_jk_F1 = F.mu_jk     
    gen mu_kk_F1 = F.mu_kk     

    preserve
        use `w_k_data', clear
        rename dest_k origin_j
        rename w_k w_j
        tempfile w_j_data
        save `w_j_data'
    restore
    merge m:1 year `demog' origin_j using `w_j_data', keep(master match) nogenerate
    xtset route_id year
    gen w_j_F1 = F.w_j


    * --- 4. CONSTRUCT THE FINAL ESTIMATING EQUATIONS ---
    gen future_wage_diff = w_k_F1 - w_j_F1
    gen future_cont_val = log(mu_jk_F1 / mu_kk_F1)
    gen y_ols = log(mu_jk / mu_jj)
    gen y_ppml = (mu_jk / mu_jj)

    * Lagged IVs
    gen iv_wage_diff = L.future_wage_diff
    gen iv_cont_val = L.future_cont_val

    keep year `demog' origin_j dest_k y_ols y_ppml future_wage_diff future_cont_val iv_wage_diff iv_cont_val
    drop if missing(future_wage_diff) | missing(future_cont_val) | missing(iv_wage_diff) | missing(iv_cont_val)

    compress
    save "$clean/cdp_estimation_data_`ds'.dta", replace
}

di ">>> Step 4 Complete. Both estimation datasets saved."
