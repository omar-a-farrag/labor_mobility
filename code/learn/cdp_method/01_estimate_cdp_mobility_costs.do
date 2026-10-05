********************************************************************************
/* Step 01: Structural Estimation of Mobility Costs (CDP 2019)
   Omar Farrag and Gary Lyn
   Created: 03-26-2026
   Last Edited: 03-26-2026
   
   Updates: 
   - Runs the Euler equation using both OLS and PPML.
   - Recovers the structural parameters (beta and nu).
*/
********************************************************************************
clear all
macro drop _all

cd "/if/research-eme/omar/Gary/mobility_project/code/learn"

do "../initialize.do" "01_estimate_cdp_mobility_costs"

di ">>> Starting Step 5: Structural Estimation"

* Ensure required packages are installed
capture ssc install ivreghdfe
capture ssc install ivreg2

* Define the two datasets to loop over
local datasets "macro granular"

foreach ds of local datasets {
    di "=========================================================="
    di ">>> STARTING ESTIMATIONS FOR DATASET: `ds'"
    di "=========================================================="
    
    use "$clean/cdp_estimation_data_`ds'.dta", clear
    
    eststo clear
    capture drop v_wage v_cont

    * --- MODEL 1: VANILLA OLS ---
    di ">>> Running M1: Vanilla OLS..."
    quietly eststo m1: reghdfe y_ols future_wage_diff future_cont_val, absorb(origin_j dest_k) vce(robust)
    
    * --- MODEL 2: VANILLA PPML ---
    di ">>> Running M2: Vanilla PPML..."
    quietly eststo m2: ppmlhdfe y_ppml future_wage_diff future_cont_val, absorb(origin_j dest_k) vce(robust)
    
    * --- MODEL 3: 2SLS (LAGGED IV) ---
    di ">>> Running M3: 2SLS..."
    quietly eststo m3: ivreghdfe y_ols (future_wage_diff future_cont_val = iv_wage_diff iv_cont_val), absorb(origin_j dest_k) robust
    
    * --- MODEL 4: PPML-IV (CONTROL FUNCTION) ---
    di ">>> Running M4: PPML-CF..."
    quietly reghdfe future_wage_diff iv_wage_diff iv_cont_val, absorb(origin_j dest_k) resid
    predict v_wage, resid
    
    quietly reghdfe future_cont_val iv_wage_diff iv_cont_val, absorb(origin_j dest_k) resid
    predict v_cont, resid
    
    quietly eststo m4: ppmlhdfe y_ppml future_wage_diff future_cont_val v_wage v_cont, absorb(origin_j dest_k) vce(robust)
    
    * --- EXPORT RESULTS ---
    esttab m1 m2 m3 m4 using "$regression_results/cdp_estimates_`ds'.csv", replace ///
        title("Structural Estimation of Mobility Costs (`ds' data)") ///
        mtitles("OLS" "PPML" "2SLS" "PPML-IV") ///
        b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
        addnotes("Origin and Destination FEs included.")
        
    di ">>> Finished `ds' dataset. Results saved."
}

di ">>> ALL ESTIMATIONS COMPLETE."
