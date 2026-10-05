********************************************************************************
/* Master Initialization Script - Labor Mobility Pipeline (CDP & Heterogeneity)
   Updates: User-dependent paths, 5% Sample Flag, Dynamic Logging, & Globals
   Authors: Omar Farrag and Gary Lyn
   Created: 2026-03-25
   Last Edited: 03-25-2026
*/
********************************************************************************
clear all
set more off
set maxvar 10000 // Essential when pulling wide ASEC extracts from IPUMS

* --- CHECK FOR REQUIRED PACKAGES ---
capture which gtools
if _rc != 0 {
    di ">>> gtools not found. Installing from SSC..."
    ssc install gtools, replace
}

capture which reghdfe
if _rc != 0 {
    di ">>> reghdfe not found. Installing from SSC..."
    ssc install reghdfe, replace
}


capture which ppmlhdfe
if _rc != 0 {
    di ">>> ppmlhdfe not found. Installing from SSC..."
    ssc install ppmlhdfe, replace
}

capture which estout
if _rc != 0 {
    di ">>> estout not found. Installing from SSC..."
    ssc install estout, replace
}

capture which ivreghdfe
if _rc != 0 {
    di ">>> ivreghdfe not found. Installing from SSC..."
    ssc install ivreghdfe, replace
}

capture which ivreg2
if _rc != 0 {
    di ">>> ivreg2 not found. Installing from SSC..."
    ssc install ivreg2, replace
}

capture which ranktest
if _rc != 0 {
    di ">>> ranktest not found. Installing from SSC..."
    ssc install ranktest, replace
}

* --- 1. USER & ENVIRONMENT SELECTION ---
global user = 2       // 1 = Windows, 2 = Linux
global use_sample = 0 // 1 = Use 5% Sample for debugging; 0 = Use Full Data


* --- 2. PATH DEFINITIONS ---
* Abstracting the root to make sharing with your co-author seamless
if $user == 1 {
    global project_root "REPLACE WITH YOUR PATH"
}
else if $user == 2 {
    global project_root "REPLACE WITH YOUR PATH"
}

* --- 3. DIRECTORY HIERARCHY ---
global data     "$project_root/data"
global raw_full "$data/raw"
global sample   "$data/sample"
global clean    "$data/clean"

global code     "$project_root/code"
global code_build "$code/build"
global code_learn "$code/learn"
global logs     "$code/logs"

global output   "$project_root/output"
global tables   "$output/tables"
global figures  "$output/figures"
global regression_results "$output/regression_results"

* Redirect $data_in based on the sample flag
global data_in = cond($use_sample == 1, "$sample", "$raw_full")

* Ensure directories exist (prevents errors on fresh clones)
foreach dir in "$code_build" "$code_learn" "$sample" "$clean" "$output" "$tables" "$figures" "$logs" "$regression_results" {
    capture mkdir "`dir'"
}

* --- 4. PROJECT-SPECIFIC GLOBALS ---
* Define demographic and sample cutoffs here so they are completely dynamic.
* When evaluating mobility for different groups, change it here, not in the cleaning scripts.
global start_year   1970
global end_year     2025
global min_age      16
global max_age      64
global min_wage     50    // Threshold to drop severe outliers/measurement error

* --- 5. DYNAMIC LOGGING SETUP ---
args calling_file
if "`calling_file'" != "" {
    capture log close
    local c_date = subinstr("`c(current_date)'", " ", "_", .)
    log using "$logs/`calling_file'_`c_date'.log", replace
    di ">>> Logging to: $logs/`calling_file'_`c_date'.log"
}

di ">>> Initialization Complete."
di ">>> User: $user | Sample Flag: $use_sample"
di ">>> Target Input Directory: $data_in"
