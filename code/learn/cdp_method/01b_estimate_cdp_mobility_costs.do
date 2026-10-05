  ********************************************************************************
/* Step 06: Recover Pecuniary Moving Costs (C_jk) Matrices
   Omar Farrag and Gary Lyn
   Created: 03-26-2026
   Last Edited: 03-26-2026
   
   Updates:
   - Loops over both Macro and Granular datasets.
   - Loops over 4 specifications: OLS, PPML, 2SLS, PPML-IV.
   - Restricts Beta = 0.96 across ALL models to calculate C_jk.
*/
********************************************************************************
clear all
macro drop _all
cd "/if/research-eme/omar/Gary/mobility_project/code/learn"
do "../initialize.do" "06_estimate_all_cost_matrices"

di ">>> Starting Step 6: Estimating ALL C_jk Moving Cost Matrices"

local datasets "macro granular"
local models "ols ppml iv_ols iv_ppml"

foreach ds of local datasets {
    di "=========================================================="
    di ">>> DATASET: `ds'"
    di "=========================================================="
    
    use "$clean/cdp_estimation_data_`ds'.dta", clear
    egen route_id = group(origin_j dest_k)

    * --- RESTRICTION SETUP ---
    * For OLS/2SLS: Move the restricted beta to the LHS
    gen y_ols_restricted = y_ols - (0.96 * future_cont_val)
    
    * For PPML/PPML-IV: Use as an offset
    gen ppml_offset = 0.96 * future_cont_val

    * First Stage CF Residuals for IV models
    quietly reghdfe future_wage_diff iv_wage_diff iv_cont_val, absorb(origin_j dest_k) resid
    predict v_wage, resid
    quietly reghdfe future_cont_val iv_wage_diff iv_cont_val, absorb(origin_j dest_k) resid
    predict v_cont, resid

    foreach m of local models {
        di "   -> Running Specification: `m'"
        
        eststo clear
        capture drop FE_`m' cost_`m'

        * 1. RUN THE RESTRICTED REGRESSIONS
        if "`m'" == "ols" {
            quietly eststo: reghdfe y_ols_restricted future_wage_diff, absorb(FE_`m' = route_id) vce(robust)
        }
        else if "`m'" == "ppml" {
            quietly eststo: ppmlhdfe y_ppml future_wage_diff, absorb(FE_`m' = route_id) offset(ppml_offset) vce(robust)
        }
        else if "`m'" == "iv_ols" {
            quietly eststo: ivreghdfe y_ols_restricted (future_wage_diff = iv_wage_diff iv_cont_val), absorb(FE_`m' = route_id) robust
        }
        else if "`m'" == "iv_ppml" {
            quietly eststo: ppmlhdfe y_ppml future_wage_diff v_wage v_cont, absorb(FE_`m' = route_id) offset(ppml_offset) vce(robust)
        }

        * Export the regression stats to grab the wage coefficient
        esttab using "$regression_results/restricted_`m'_`ds'.csv", replace ///
            b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) keep(future_wage_diff)

        * 2. RECOVER C_jk
        local nu_`m' = 0.96 / _b[future_wage_diff]
        
        * Safely grab the constant (ivreghdfe absorbs it differently)
        capture scalar cons_`m' = _b[_cons]
        if _rc != 0 scalar cons_`m' = 0

        gen cost_`m' = -1 * `nu_`m'' * (FE_`m' + cons_`m')
        replace cost_`m' = 0 if origin_j == dest_k

        * 3. FORMAT MATRIX
        preserve
        keep if inrange(origin_j, 1, 6) & inrange(dest_k, 1, 6)
        keep origin_j dest_k cost_`m'
        duplicates drop

        reshape wide cost_`m', i(origin_j) j(dest_k)
        rename cost_`m'1 Ag_Min
        rename cost_`m'2 Construct
        rename cost_`m'3 Manufac
        rename cost_`m'4 Trade
        rename cost_`m'5 Service
        rename cost_`m'6 Trans_Util

        export delimited using "$regression_results/cost_matrix_`m'_`ds'.csv", replace
        restore
    }
}
di ">>> ALL MATRICES EXPORTED."
   
