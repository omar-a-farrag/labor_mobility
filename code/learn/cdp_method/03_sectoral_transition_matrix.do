********************************************************************************
/* Step 06: Generate Sector Transition Matrix (ACM Style) */
********************************************************************************
clear all
cd "/if/research-eme/omar/Gary/mobility_project/code/learn"
do "../initialize.do" "03_sectoral_transition_matrix"

use "$clean/gross_flows_matrix.dta", clear

* Collapse out the demographics and years to get raw macro flows
collapse (sum) gross_flow, by(origin_j dest_k)

* Calculate total flow out of each origin
bysort origin_j: egen total_origin = sum(gross_flow)

* Calculate the transition probability (%)
gen transition_pct = (gross_flow / total_origin) * 100

* Format the matrix
keep origin_j dest_k transition_pct
reshape wide transition_pct, i(origin_j) j(dest_k)

* Rename columns for readability
rename transition_pct1 Ag_Mining
rename transition_pct2 Construct
rename transition_pct3 Manufac
rename transition_pct4 Trade
rename transition_pct5 Services
rename transition_pct6 Trans_Util
rename transition_pct7 Non_Emp

* Format the numbers to 2 decimal places
format Ag_Mining-Non_Emp %9.2f

list, noobs clean

* Export to CSV for LaTeX formatting later
export delimited using "$tables/transition_matrix_raw.csv", replace
di ">>> Transition Matrix exported to $tables"
