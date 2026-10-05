################################################################################
### Script 1: API Pull - China Exports to Partners (ANNUAL)
################################################################################
rm(list=ls())
library(httr); library(jsonlite); library(dplyr); library(this.path)
setwd(dirname(this.path()))

# ==============================================================================
# CONFIGURATION
# ==============================================================================
SUB_KEY <- "0a242e4bfc484d6fa478762aa9176b08" 
SKIP_EXISTING <- TRUE 

set_config(use_proxy('wwwproxy.frb.gov', 8080), override = FALSE)
set_config(user_agent('Lynx'), override = FALSE)

country_map <- list(
  "ar"="32", "bz"="76", "ca"="124", "co"="170", "cl"="152", "ch"="156",
  "ge"="276", "hk"="344", "id"="360", "in"="699", "jn"="392", "ko"="410",
  "ma"="458", "mx"="484", "ph"="608", "si"="702", "ta"="490", "th"="764",
  "uk"="826", "us"="842", "vt"="704"
)
target_years <- 1992:2015

# ==============================================================================
# HELPER FUNCTION
# ==============================================================================
comtrade_api_call <- function(reporter_code, partner_code, period, key) {
  # ---> THE FIX: Changed /C/M/HS to /C/A/HS for Annual data <---
  url <- modify_url("https://comtradeapi.un.org/data/v1/get/C/A/HS", 
                    query = list("subscription-key"=key, 
                                 "reporterCode"=reporter_code, 
                                 "partnerCode"=partner_code, 
                                 "period"=period, 
                                 "cmdCode"="AG6", 
                                 "flowCode"="X", 
                                 "breakdownMode"="classic", 
                                 "includeDesc"="true")) 
  
  res <- RETRY("GET", url, times = 3, pause_min = 2)
  
  if (status_code(res) == 403) {
    stop("API Returned 403 Forbidden. You likely hit the daily quota. Stopping script.")
  }
  
  if (status_code(res) >= 400) {
    warning(paste("API Error:", status_code(res)))
    return(NULL)
  }
  
  json_data <- fromJSON(content(res, "text", encoding = "UTF-8"))
  if (is.null(json_data$data) || length(json_data$data) == 0) return(NULL)
  
  df <- json_data$data
  names(df) <- tolower(names(df))
  return(df)
}

# ==============================================================================
# EXECUTION
# ==============================================================================
if (SKIP_EXISTING) {
  cat("STARTING: Resume Mode (Skipping existing files)...\n")
} else {
  cat("STARTING: Update Mode (Overwriting existing files)...\n")
}

# ---> THE FIX: Save to an 'annual' folder <---
dir.create("../../data/raw/exports/annual/", recursive = TRUE, showWarnings = FALSE)

for (abbr in names(country_map)) {
  if(abbr == "ch") next 
  
  output_file <- paste0("../../data/raw/exports/annual/comtrade_china_exports_to_", abbr, ".csv")
  
  if (file.exists(output_file) && SKIP_EXISTING) {
    cat("Skipping", abbr, "(File exists)\n")
    next
  }
  
  partner_id <- country_map[[abbr]]
  all_years_data <- list()
  cat("--------------------------------------------------\n")
  cat("Fetching China Exports to:", abbr, "(Annual)...\n")
  
  tryCatch({
    for (yr in target_years) {
      cat("   ", yr, "... ")
      
      # ---> THE FIX: Just pass the year string (e.g., "1992") <---
      chunk <- comtrade_api_call(reporter_code = "156", 
                                 partner_code = partner_id, 
                                 period = as.character(yr), 
                                 key = SUB_KEY)
      
      if (!is.null(chunk)) {
        all_years_data[[as.character(yr)]] <- chunk
        cat("Success (", nrow(chunk), "rows)\n")
      } else { 
        cat("No Data\n") 
      }
      Sys.sleep(2) # Protect against 429s
    }
    
    if (length(all_years_data) > 0) {
      final_df <- bind_rows(all_years_data)
      write.csv(final_df, output_file, row.names = FALSE)
      cat(">> SAVED:", abbr, "\n")
    } else {
      cat(">> NO DATA found for", abbr, "\n")
    }
    
  }, error = function(e) {
    cat("\n!!!!! CRITICAL ERROR !!!!!\n")
    cat(e$message, "\n")
    stop(e$message) 
  })
}
cat("Script 1 Complete.\n")
