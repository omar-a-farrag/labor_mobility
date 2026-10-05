********************************************************************************
/* Step 03: Construct Demographic and Sector Aggregates
   Omar Farrag and Gary Lyn
   Created: 03-25-2026
   Last Edited: 03-25-2026
   
   Updates: 
   - Strict adherence to project's historical occ1990/ind1990 mappings.
   - Creates orthogonal demographic types (Education and Collar).
   - Routes non-employed individuals to Sector 7 to preserve CDP state space.
*/
********************************************************************************
clear all
macro drop _all


** Set Script Directory, based on whether we are in Windows or Linux
*cd "Z:/prod-eme/usr/omar/Research/Gary/mobility_project" /// Windows

cd "/if/research-eme/omar/Gary/mobility_project/code/build" /// Linux


do "../initialize.do" "03_construct_aggregates"

di ">>> Starting Step 3: Sector and Demographic Aggregation"

* --- 1. LOAD THE LINKED PANEL ---
use "$clean/ipums_asec_panel_linked.dta", clear

* --- 2. DEFINE ORTHOGONAL WORKER TYPES ---
di ">>> Generating Orthogonal Worker Types (Educ and Collar)..."

* Type A: Education (Based on historical project ledger)
gen educ_type = .
replace educ_type = 1 if inrange(educ, 2, 73)   // No College Degree
replace educ_type = 2 if inrange(educ, 80, 125) // Some College or Higher
drop if educ == 999 | educ == 0 | educ == .     // Drop Missing/NIU

* Type B: Collar (Using project occ1990 ledger)
gen collar_type = .
* 000-400: Managerial, Professional, Tech, Sales, Admin, Misc White Collar
replace collar_type = 1 if inrange(occ1990, 0, 400) 
* 405-900: Service, Farming, Craft, Operators, Laborers
replace collar_type = 2 if inrange(occ1990, 405, 900)

* Drop Military (905) and NIU (999) from the structural estimation
drop if collar_type == . 


* --- 3. DEFINE THE SECTORS (Using project ind1990 ledger) ---
di ">>> Generating Sectors..."

foreach yr in "" "_2" {
    
    * Start by defaulting everyone to Sector 7 (Non-Employed)
    * This captures anyone where empstat is NOT 10 (at work) or 12 (leave)
    gen sector`yr' = 7 
    
    * Use a temporary flag for "Employed" to make the sector logic cleaner
    tempvar is_employed`yr'
    gen `is_employed`yr'' = (empstat`yr' == 10 | empstat`yr' == 12)
    
    * 5. SERVICES (Catch-all for 0-939, applied first so others overwrite it)
    replace sector`yr' = 5 if inrange(ind1990`yr', 0, 939) & `is_employed`yr'' == 1
    
    * 1. AGRICULTURE & MINING
    replace sector`yr' = 1 if inrange(ind1990`yr', 10, 50) & `is_employed`yr'' == 1
    
    * 2. CONSTRUCTION
    replace sector`yr' = 2 if ind1990`yr' == 60 & `is_employed`yr'' == 1
    
    * 3. MANUFACTURING
    replace sector`yr' = 3 if inrange(ind1990`yr', 100, 392) & `is_employed`yr'' == 1
    
    * 4. WHOLESALE AND RETAIL TRADE
    replace sector`yr' = 4 if inrange(ind1990`yr', 500, 691) & `is_employed`yr'' == 1
    
    * 6. TRANS/UTIL (Transportation and Utilities)
    replace sector`yr' = 6 if inrange(ind1990`yr', 400, 472) & `is_employed`yr'' == 1
}

* Apply clean labels matching the historical ledger
label define sec_lbl 1 "Agric/Min" 2 "Construction" 3 "Manufacturing" ///
                     4 "Trade" 5 "Services" 6 "Trans/Util" 7 "Non-Employed"
label values sector sec_lbl
label values sector_2 sec_lbl

* ---> Save the classified microdata for Step 04! <---
save "$clean/ipums_asec_panel_classified_granular.dta", replace
* ----------------------------------------------------------

* --- 4. COLLAPSE INTO TRANSITION MATRICES ---
di ">>> Collapsing microdata into gross flow transition matrices..."

* The state space: Year x Educ x Collar x Origin x Destination
collapse (sum) gross_flow = asecwth, by(year educ_type collar_type sector sector_2)

* Rename for spatial/structural conventions
rename sector origin_j
rename sector_2 dest_k

* Clean up and save
order year educ_type collar_type origin_j dest_k gross_flow
sort year educ_type collar_type origin_j dest_k

compress
save "$clean/gross_flows_matrix.dta", replace

di ">>> Step 3 Complete. State Space Matrix saved to $clean"

********************************************************************************
** APPENDIX: 
*  Description of Variables and How Obs. were Sorted into Aggregate Categories
********************************************************************************

* ==============================================================================
*                   Assign sector categories by ind1990
* ==============================================================================


*  AGRICULTURE, Forestry, and Fisheries Ledger:
* 010 - Ag production; crops
* 011 - Ag production; livestock
* 012 - Veterinary services
* 020 - Landscape and horticultural services
* 030 - Agricultural services, n.e.c.
* 031 - Forestry
* 032 - Fishing, hunting, and trapping

* MINING Ledger:

* 040 - Metal mining
* 041 - Coal mining
* 042 - Oil and gas extraction
* 050 - Nonmetallic mining and quarrying, except fuels

* CONSTRUCTION Ledger:
* 060 - Construction

* MANUFACTURING Ledger:
* 100?199 - Nondurable manufacturing (e.g., food, textiles, chemicals)
* 200?299 - Durable manufacturing (e.g., furniture, machinery, electronics)
* 300-392 - Machinary 

* WHOLESALE AND RETAIL TRADE Ledger:
* 500 - Wholesale trade: durable goods
* 510 - Wholesale trade: nondurable goods
* 521 - Motor vehicles and equipment dealers
* 522 - Furniture and home furnishings stores
* 523 - Electronics and appliance stores
* 524 - Building materials, hardware, garden supply
* 525 - Grocery stores
* 526 - Other food stores
* 530 - Pharmacies and drug stores
* 531 - Gasoline stations
* 532 - Clothing and accessories stores
* 540?571 - Miscellaneous retail
* 580?691 - Remaining retail trade (including general merchandise, e-commerce, etc.)

/*
* SERVICES:
replace sector = "Service" if sector=="" & ind1990_2>=0 & ind1990_2<940

* Prior year, SERVICES:
replace sector_ly = "Service" if sector_ly=="" & ind1990_1>=0 & ind1990_1<940

* Military Personnel
replace sector = "Trans/Util" if inrange(ind1990_2, 400, 472)

* Prior year, Military Personnel
replace sector_ly = "Trans/Util" if inrange(ind1990_1, 400, 472)

* Ledger:
* All remaining industries not assigned above, including:
* - Transportation and warehousing (300?399)
* - Utilities
* - Finance, insurance, and real estate (700?760)
* - Professional services, education, health, entertainment, etc.
* - Public administration, armed forces


*/

/* Ledger-style record of what the occupations we assigned are in occ1990

WHITE-COLLAR WORKER:
000?199  - Managerial and professional specialty occupations
200?235  - Technical occupations
243?285  - Sales occupations
303?389  - Administrative support, including clerical
400      - Misc. white-collar, n.e.c.

BLUE-COLLAR WORKER:
405?469  - Service occupations (e.g., protective, food prep, cleaning)
473?499  - Farming, forestry, and fishing
503?699  - Precision production, craft, and repair
703?889  - Machine operators, assemblers, inspectors
891?900  - Laborers and material movers

MILITARY:
905      - Armed Forces

NIU:
999      - Not in Universe (not working or not applicable)

*/

/*

* Assign No College Experience
replace educ_type = 1 if inrange(educ_2, 2, 73)

* Assign blue-collar (2)
replace educ_type = 2 if inrange(educ_2, 80, 125)

* Assign Missing/unknown or NIU(3)
replace worker_type = 3 if educ_2 == 999 | educ_2 == 000

* Define value labels
label define ed_lbl ///
    1 "No College" ///
    2 "Some College or More" ///
    3 "Missing or NIU" 

*/

/*
IPUMS note on ind variable:
For persons who were employed at the time of the survey, IND relates to the industrial sector in which the respondent worked during the preceding week. For unemployed persons and those not currently in the labor force, IND characterizes the industrial sector of the respondent's most recent job. The CPS interviewer collected information by asking what kind of work the person was doing, and Census Bureau staff coded the information into the CPS or census industrial classification. Researchers who wish to work with a consistent industrial coding scheme for 1968 forward should use the IND1950 variable. For general discussion of employment concepts, including the definition of those not in the labor force, see the documentation on EMPSTAT.



IPUMS note on occ variable:
OCC reports the person's primary occupation. Respondents who held more than one job were to report the job at which they worked the largest number of hours. For persons who were employed at the time of the survey, OCC relates to the job worked during the preceding week; unemployed persons and those not currently in the labor force were to give their most recent occupation. The CPS interviewer collected information by asking what kind of work the person was doing, and Census Bureau staff coded the information into the contemporary CPS or census occupational classification. Researchers who wish to work with a consistent occupational coding scheme for 1968 forward should use the OCC1950 variable. For general discussion of employment concepts, including the definition of those not in the labor force, see the documentation on EMPSTAT.

////////////////////////////////////////////////////////////////////////////////
SECTOR CLASSIFICATION ASSIGNED TO IND VARIABLE OBSERVATIONS (using ind1990 aggregation scheme)
link to codes: https://cps.ipums.org/cps-action/variables/IND1990#codes_section
Universe: Persons age 15+ who - were currently employed; or had previously worked and were looking for work; or were not currently in the labor force but had worked in the preceding 5 years.



////////////////////////////////////////////////////////////////////////////////
WORKER-TYPE CLASSIFICATION ASSIGNED TO OCC VARIABLE OBSERVATIONS (using occ1990 aggregation scheme)
link to codes:https://cps.ipums.org/cps-action/variables/OCC1990#codes_section 
Universe: for 1994 and onward - Civilians age 15+ who were employed, on layoff, unemployed but had worked in the past, or not in labor force but had worked in the past year

999 - NIU


////////////////////////////////////////////////////////////////////////////////
EDUCATION-TYPE CLASSIFICATION ASSIGNED TO EDUC VARIABLE OBSERVATIONS: 
link to codes: https://cps.ipums.org/cps-action/variables/EDUC#codes_section
