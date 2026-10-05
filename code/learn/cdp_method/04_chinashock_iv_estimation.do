********************************************************************************
/* Step 07: The China Shock Bartik IV
   Omar Farrag and Gary Lyn
   
   Methodology:
   - Maps HS6 codes to Tradable Macro Sectors (Ag/Min and Manufac).
   - Assumes Non-Tradable sectors receive 0 direct trade shock.
   - Calculates exogenous trade growth from high-income partners.
   - Instruments the future wage difference (w_k - w_j) with the trade shock.
*/
********************************************************************************
clear all
macro drop _all
cd "/if/research-eme/omar/Gary/mobility_project/code/learn"
do "../initialize.do" "04_chinashock_iv_estimation.do"

di ">>> Starting Step 7: Building the China Shock IV"

* --- 1. PROCESS THE TRADE DATA ---
import delimited "../../data/cleaned/exports/annual/global_china_shock_hs6.csv", clear

* Ensure HS codes are cleanly formatted strings (pad leading zeros)
tostring hs6, replace
replace hs6 = "0" + hs6 if length(hs6) == 5

* Extract the 2-digit HS Chapter
gen hs2 = real(substr(hs6, 1, 2))

* Assign to Tradable Macro Sectors
gen sector = .
replace sector = 1 if inrange(hs2, 1, 27)   // Agriculture & Mining
replace sector = 3 if inrange(hs2, 28, 97)  // Manufacturing

* Drop unmapped (like special codes 98/99)
drop if missing(sector)

* Collapse to total global supply shock by Sector x Year
collapse (sum) total_exports_usd, by(year sector)

* Calculate Log Trade and Year-over-Year Growth (The "Shift")
xtset sector year
gen log_exports = log(total_exports_usd)
gen trade_growth = D.log_exports

keep year sector trade_growth
tempfile trade_shocks
save `trade_shocks'

* --- 2. MERGE SHOCKS INTO ESTIMATION DATA ---
di ">>> Merging Shocks into Macro Estimation Data..."
use "$clean/cdp_estimation_data_macro.dta", clear

* A. Merge Destination Shock (Sector K)
preserve
    use `trade_shocks', clear
    rename sector dest_k
    rename trade_growth shock_k
    tempfile shock_k_data
    save `shock_k_data'
restore
merge m:1 year dest_k using `shock_k_data', keep(master match) nogenerate

* B. Merge Origin Shock (Sector J)
preserve
    use `trade_shocks', clear
    rename sector origin_j
    rename trade_growth shock_j
    tempfile shock_j_data
    save `shock_j_data'
restore
merge m:1 year origin_j using `shock_j_data', keep(master match) nogenerate

* C. Handle Non-Tradables (0 Shock)
replace shock_k = 0 if missing(shock_k)
replace shock_j = 0 if missing(shock_j)

egen route_id = group(origin_j dest_k)
xtset route_id year

* D. Create the Forward (t+1) Instrument 
* (Because workers at time t react to the anticipated shock at t+1)
gen iv_shock_diff = F.shock_k - F.shock_j

* Drop years where we don't have future trade data
drop if missing(iv_shock_diff)

* --- 3. RUN THE CHINA SHOCK IV ESTIMATION ---
di "=========================================================="
di " MODEL: CHINA SHOCK IV (PPML-CF)"
di "=========================================================="

* First Stage: Predict the Wage Difference using the Trade Shock
quietly reghdfe future_wage_diff iv_shock_diff iv_cont_val, absorb(origin_j dest_k) resid
predict v_wage_trade, resid

* First Stage: Predict Continuation Value 
quietly reghdfe future_cont_val iv_shock_diff iv_cont_val, absorb(origin_j dest_k) resid
predict v_cont_trade, resid

* Second Stage: PPML with Trade Control Functions
ppmlhdfe y_ppml future_wage_diff future_cont_val v_wage_trade v_cont_trade, absorb(origin_j dest_k) vce(robust)

local beta_trade = _b[future_cont_val]
local nu_trade   = `beta_trade' / _b[future_wage_diff]

di ""
di ">>> CHINA SHOCK IV Implied Discount Factor (beta): " `beta_trade'
di ">>> CHINA SHOCK IV Implied Shock Dispersion (nu):  " `nu_trade'

* Export the clean log for Python later
eststo clear
eststo: ppmlhdfe y_ppml future_wage_diff future_cont_val v_wage_trade v_cont_trade, absorb(origin_j dest_k) vce(robust)

esttab using "$regression_results/china_shock_ppml.csv", replace ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)
