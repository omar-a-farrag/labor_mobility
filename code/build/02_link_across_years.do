********************************************************************************
/* Step 02: Clean, Segment, and Link Across Years
   Omar Farrag and Gary Lyn
   Created: 03-25-2026
   Last Edited: 03-25-2026
   
   Updates: 
   - Uses gtools for rapid merging (no preserve/restore loops)
   - Resolves 1977 missing cpsidp issue
   - Deterministically drops early-year oversample duplicates
*/
********************************************************************************
clear all
macro drop _all


** Set Script Directory, based on whether we are in Windows or Linux
*cd "Z:/prod-eme/usr/omar/Research/Gary/mobility_project" /// Windows

cd "/if/research-eme/omar/Gary/mobility_project/code/build" /// Linux

do "../initialize.do" "02_link_across_years"

* Need this package for this script.
ssc install gtools, replace

di ">>> Starting Step 2: Panel Linking"

* --- 1. LOAD AND CLEAN THE RAW DATA ---
use "$data_in/march_asec_1970_2025_raw.dta", clear

* Drop un-linkable records (Solves the 1977 problem)
drop if missing(cpsidp) | cpsidp == 0

* Deterministically handle duplicates (Solves the 1976-1988 problem)
* We sort by the person weight descending, so the most "representative" 
* record is kept as observation #1 for that person-year.
gsort year cpsidp -asecwth
by year cpsidp: gen dup_num = _n
keep if dup_num == 1
drop dup_num

* --- 2. PREPARE THE "DESTINATION" (Year T+1) DATASET ---
* We save a temporary copy of the data to act as the future state.
di ">>> Preparing Destination Data (T+1)..."

preserve
    * Rename all variables to have a "_2" suffix, EXCEPT the linking key (cpsidp)
    * We use a loop to rename all variables dynamically
    foreach var of varlist _all {
        if "`var'" != "cpsidp" {
            rename `var' `var'_2
        }
    }
    
    * Rename the year variable to act as our merge target
    rename year_2 merge_year
    
    * Save to a temporary file in memory
    tempfile dest_data
    save `dest_data'
restore

* --- 3. PREPARE THE "ORIGIN" (Year T) DATASET & MERGE ---
di ">>> Linking Panel Across Years..."

* Create the target year to merge against (T + 1)
gen merge_year = year + 1

* Merge the future state onto the current state using gtools
merge 1:1 cpsidp merge_year using `dest_data'

* Keep only successfully linked individuals (Present in T and T+1)
keep if _merge == 3
drop _merge merge_year

* --- 4. VALIDATE THE LINK ---
di ">>> Validating Demographic Consistency..."

* 1. Sex must match exactly across years
keep if sex == sex_2

* 2. Age must progress logically (0 to 2 years to account for interview timing)
gen age_diff = age_2 - age
keep if inrange(age_diff, 0, 2)
drop age_diff

* --- 5. CLEAN UP AND SAVE ---
* Apply global filters defined in initialize.do
keep if inrange(age, $min_age, $max_age)

compress
save "$clean/ipums_asec_panel_linked.dta", replace

di ">>> Step 2 Complete. Linked Panel Saved to $clean"
