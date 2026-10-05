********************************************************************************
/* Step 04: Prepare Variables for CDP (2019) Structural Estimation
   Omar Farrag and Gary Lyn
   Created: 03-25-2026
   Last Edited: 03-26-2026
   
   Updates: 
   - Loads the pre-classified microdata from Step 03.
   - Switched wage calculation to rely on earnweek2_2 and uhrswork1_2
   - Calculates forward-looking (t+1) variables for the CDP Euler Equation
   - Prepares dependent variables for both OLS (logs) and PPML (levels)
*/
********************************************************************************
clear all
macro drop _all

** Set Script Directory
cd "/if/research-eme/omar/Gary/mobility_project/code/build" /// Linux

do "../initialize.do" "04_prep_cdp_variables"

di ">>> Starting Step 4: Preparing CDP Estimation Variables"

* --- 1. EXTRACT MEAN SECTOR WAGES ---
di ">>> Calculating Mean Expected Wages by Sector..."

* ---> Load the classified data instead of the raw linked data <---
use "$clean/ipums_asec_panel_classified.dta", clear

* Drop the baked-in tempvars from Step 03
capture drop __*

* Calculate hourly wage using Weekly Earnings / Usual Hours
* Drop missing/NIU codes for earnings (9999) and hours (999)
keep if earnweek2_2 > 0 & earnweek2_2 < 9999
keep if uhrswork1_2 > 0 & uhrswork1_2 < 999

gen hourly_wage = earnweek2_2 / uhrswork1_2

* Drop severe outliers and keep only employed individuals for the wage calculation
keep if hourly_wage >= 1 & hourly_wage <= 200 
keep if inrange(empstat_2, 10, 12)            

* Calculate the mean LOG wage by Year, Education, Collar Type, and Sector
gen log_wage = log(hourly_wage)
collapse (mean) mean_log_wage = log_wage [pw=asecwth], by(year educ_type collar_type sector_2)

* Rename to match spatial destination k
rename sector_2 dest_k
rename mean_log_wage w_k

tempfile w_k_data
save `w_k_data'


* --- 2. CALCULATE TRANSITION PROBABILITIES (mu) ---
di ">>> Calculating Transition Probabilities (mu)..."

use "$clean/gross_flows_matrix.dta", clear

* Calculate total flow out of origin j at time t for a specific demographic type
bysort year educ_type collar_type origin_j: egen total_flow_j = sum(gross_flow)

* Calculate mu_jk (Probability of moving j -> k)
gen mu_jk = gross_flow / total_flow_j

* Isolate the "Stayer" probability (mu_jj) and merge it back to all rows
preserve
    keep if origin_j == dest_k
    keep year educ_type collar_type origin_j mu_jk
    rename mu_jk mu_jj
    tempfile stayers_j
    save `stayers_j'
restore

merge m:1 year educ_type collar_type origin_j using `stayers_j', keep(master match) nogenerate

* We also need the destination stayer probability (mu_kk) for the future continuation value
preserve
    use `stayers_j', clear
    rename origin_j dest_k
    rename mu_jj mu_kk
    tempfile stayers_k
    save `stayers_k'
restore

merge m:1 year educ_type collar_type dest_k using `stayers_k', keep(master match) nogenerate


* --- 3. ASSEMBLE THE PANEL & CREATE T+1 LEADS ---
di ">>> Creating Panel Structure and Forward Expectations (t+1)..."

* Merge in the wages for destination k
merge m:1 year educ_type collar_type dest_k using `w_k_data', keep(master match) nogenerate

* Set up the Panel Data Structure
* A "panel" here is a specific migration route for a specific demographic intersection
egen route_id = group(educ_type collar_type origin_j dest_k)
xtset route_id year

* Create the Future (t+1) Expectation Variables using the forward operator (F.)
gen w_k_F1   = F.w_k       // Future wage in dest k
gen mu_jk_F1 = F.mu_jk     // Future transition share j -> k
gen mu_kk_F1 = F.mu_kk     // Future stayer share in dest k

* Merge in the future wage for the ORIGIN (w_j at t+1) to calculate the wage difference
preserve
    use `w_k_data', clear
    rename dest_k origin_j
    rename w_k w_j
    tempfile w_j_data
    save `w_j_data'
restore
merge m:1 year educ_type collar_type origin_j using `w_j_data', keep(master match) nogenerate
xtset route_id year
gen w_j_F1 = F.w_j


* --- 4. CONSTRUCT THE FINAL ESTIMATING EQUATIONS ---
di ">>> Constructing OLS, PPML, and IV Variables..."

* 1. The Right-Hand Side (Endogenous Variables)
gen future_wage_diff = w_k_F1 - w_j_F1
gen future_cont_val = log(mu_jk_F1 / mu_kk_F1)

* 2. The Left-Hand Side (Dependent Variables)
gen y_ols = log(mu_jk / mu_jj)
gen y_ppml = (mu_jk / mu_jj)

* ---> The ACM Lagged Instruments <---
* We use the t-1 lags of the endogenous variables as our instruments
gen iv_wage_diff = L.future_wage_diff
gen iv_cont_val = L.future_cont_val
* --------------------------------------------------

* Clean up, format, and save for regressions
keep year educ_type collar_type origin_j dest_k y_ols y_ppml future_wage_diff future_cont_val iv_wage_diff iv_cont_val
drop if missing(future_wage_diff) | missing(future_cont_val) | missing(iv_wage_diff) | missing(iv_cont_val)

compress
save "$clean/cdp_estimation_data.dta", replace

di ">>> Step 4 Complete. Estimation Data saved to $clean."
