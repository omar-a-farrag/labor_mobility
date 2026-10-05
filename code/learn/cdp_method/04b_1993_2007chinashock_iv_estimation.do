********************************************************************************
/* Step 07: The China Shock Bartik IV (Strict CDP Parameters)
   Omar Farrag and Gary Lyn
   
   Methodology:
   - Restricts sample to the exact CDP Era (1993-2007).
   - Restricts Beta = 0.96 (Continuation value becomes an offset).
   - Instruments ONLY the future wage difference with the Trade Shock.
*/
********************************************************************************
clear all
macro drop _all
cd "/if/research-eme/omar/Gary/mobility_project/code/learn"
do "../initialize.do" "07_estimate_china_shock_iv"

di ">>> Starting Step 7: Strict China Shock IV (1993-2007, Beta=0.96)"

* --- 1. PROCESS THE TRADE DATA ---
import delimited "../../data/cleaned/exports/annual/global_china_shock_hs6.csv", clear

tostring hs6, replace
replace hs6 = "0" + hs6 if length(hs6) == 5
gen hs2 = real(substr(hs6, 1, 2))

gen sector = .
replace sector = 1 if inrange(hs2, 1, 27)   
replace sector = 3 if inrange(hs2, 28, 97)  
drop if missing(sector)

collapse (sum) total_exports_usd, by(year sector)

xtset sector year
gen log_exports = log(total_exports_usd)
gen trade_growth = D.log_exports

keep year sector trade_growth
tempfile trade_shocks
save `trade_shocks'

* --- 2. MERGE SHOCKS INTO ESTIMATION DATA ---
use "$clean/cdp_estimation_data_macro.dta", clear

* ---> STRICT ERA RESTRICTION (1993 - 2007) <---
keep if inrange(year, 1993, 2007)

preserve
    use `trade_shocks', clear
    rename sector dest_k
    rename trade_growth shock_k
    tempfile shock_k_data
    save `shock_k_data'
restore
merge m:1 year dest_k using `shock_k_data', keep(master match) nogenerate

preserve
    use `trade_shocks', clear
    rename sector origin_j
    rename trade_growth shock_j
    tempfile shock_j_data
    save `shock_j_data'
restore
merge m:1 year origin_j using `shock_j_data', keep(master match) nogenerate

replace shock_k = 0 if missing(shock_k)
replace shock_j = 0 if missing(shock_j)

egen route_id = group(origin_j dest_k)
xtset route_id year

gen iv_shock_diff = F.shock_k - F.shock_j
drop if missing(iv_shock_diff)

* --- 3. RUN THE STRICT RESTRICTED IV ESTIMATION ---
di "=========================================================="
di " MODEL: STRICT CHINA SHOCK IV (PPML-CF | Beta = 0.96)"
di "=========================================================="

* Since Beta is restricted, we move continuation value to the offset
gen ppml_offset = 0.96 * future_cont_val

* First Stage: Predict the Wage Difference using the Trade Shock
* (Notice we no longer need to predict or include the continuation value!)
quietly reghdfe future_wage_diff iv_shock_diff, absorb(origin_j dest_k) resid
predict v_wage_trade, resid

* Second Stage: PPML with Trade Control Function and restricted offset
ppmlhdfe y_ppml future_wage_diff v_wage_trade, absorb(origin_j dest_k) offset(ppml_offset) vce(robust)

* Calculate implied nu (nu = 0.96 / coefficient_on_wage)
local nu_trade = 0.96 / _b[future_wage_diff]

di ""
di ">>> STRICT CHINA SHOCK IV Implied Discount Factor (beta): 0.96 (Calibrated)"
di ">>> STRICT CHINA SHOCK IV Implied Shock Dispersion (nu):  " `nu_trade'

* Export the results
eststo clear
eststo: ppmlhdfe y_ppml future_wage_diff v_wage_trade, absorb(origin_j dest_k) offset(ppml_offset) vce(robust)

esttab using "$regression_results/china_shock_strict_ppml.csv", replace ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) keep(future_wage_diff v_wage_trade)
