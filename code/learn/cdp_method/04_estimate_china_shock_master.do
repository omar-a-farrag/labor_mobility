********************************************************************************
/* Step 07: Master China Shock IV Pipeline (Option 2 - STRICT BETA)
   Omar Farrag and Gary Lyn
   
   Methodology:
   - Loops over two time scales: Full (1992-2015) and Strict (1993-2007).
   - Calibrates Beta = 0.96 for ALL estimations.
   - Outputs restricted estimates and C_jk Cost Matrices.
*/
********************************************************************************
clear all
macro drop _all
cd "/if/research-eme/omar/Gary/mobility_project/code/learn"
do "../initialize.do" "04_estimate_china_shock_master.do"

di ">>> Starting Step 7: Master China Shock Pipeline (Beta = 0.96)"

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

* --- 2. THE ESTIMATION LOOP ---
local timeframes "full strict"

foreach tf of local timeframes {
    di "=========================================================="
    di ">>> OPTION 2 TIMEFRAME: `tf' (RESTRICTED BETA = 0.96)"
    di "=========================================================="
    
    use "$clean/cdp_estimation_data_macro.dta", clear
    
    if "`tf'" == "strict" {
        keep if inrange(year, 1993, 2007)
    }

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

    * --- RESTRICTED ESTIMATION (Beta = 0.96) ---
    gen ppml_offset = 0.96 * future_cont_val
    
    * First Stage: Predict wage diff using Trade Shock
    quietly reghdfe future_wage_diff iv_shock_diff, absorb(origin_j dest_k) resid
    predict v_wage_trade, resid

    * Second Stage: PPML-CF
    eststo clear
    quietly eststo: ppmlhdfe y_ppml future_wage_diff v_wage_trade, absorb(FE_ppml = route_id) offset(ppml_offset) vce(robust)
    
    * Save Estimates Table
    esttab using "$regression_results/opt2_restricted_estimates_`tf'.csv", replace ///
        b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) keep(future_wage_diff v_wage_trade)

    * Recover C_jk
    local nu_trade = 0.96 / _b[future_wage_diff]
    capture scalar cons_trade = _b[_cons]
    if _rc != 0 scalar cons_trade = 0

    gen cost_ppml = -1 * `nu_trade' * (FE_ppml + cons_trade)
    replace cost_ppml = 0 if origin_j == dest_k

    keep if inrange(origin_j, 1, 6) & inrange(dest_k, 1, 6)
    keep origin_j dest_k cost_ppml
    duplicates drop
    reshape wide cost_ppml, i(origin_j) j(dest_k)

    rename cost_ppml1 Ag_Min
    rename cost_ppml2 Construct
    rename cost_ppml3 Manufac
    rename cost_ppml4 Trade
    rename cost_ppml5 Service
    rename cost_ppml6 Trans_Util

    * Save Cost Matrix
    export delimited using "$tables/opt2_cost_matrix_`tf'.csv", replace
    di ">>> `tf' Data Exported."
}
di ">>> OPTION 2 MASTER PIPELINE COMPLETE."
