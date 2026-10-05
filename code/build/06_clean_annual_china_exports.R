################################################################################
### Script 2: Clean Annual China Exports (The "Shift" for Bartik IV)
################################################################################
rm(list=ls())
library(readr); library(dplyr); library(this.path)
setwd(dirname(this.path()))

cat(">>> Starting Annual China Exports Cleaning...\n")

# The high-income countries we use to instrument the US shock
# (We use China's exports to THEM to ensure the shock is exogenous to US domestic demand)
country_abbrs <- c("ca", "ge", "jn", "uk", "ko", "ar", "mx", "id", "th")

# 1. Read and Combine all the Annual Partner Files
all_data <- list()

for (abbr in country_abbrs) {
  input_file <- paste0("../../data/raw/exports/annual/comtrade_china_exports_to_", abbr, ".csv")
  
  if (!file.exists(input_file)) { 
    cat("   [Skipping] ", abbr, " (File not found)\n")
    next 
  }
  
  cat("   [Loading] ", abbr, "...\n")
  
  # Read the CSV. cmdcode is HS6, period is Year, primaryvalue is USD
  df <- read_csv(input_file, show_col_types = FALSE, col_types = cols(.default = col_character())) %>%
    rename(hs6 = cmdcode, year = period, usd = primaryvalue) %>%
    mutate(usd = as.numeric(usd), year = as.numeric(year)) %>%
    select(year, hs6, usd)
  
  all_data[[abbr]] <- df
}

# 2. Aggregate into a single "Global Shock"
cat("\n>>> Aggregating Global China Supply Shock...\n")
combined_df <- bind_rows(all_data)

# Sum exports across all partner countries by Year and HS6 Product
global_shock_hs6 <- combined_df %>%
  group_by(year, hs6) %>%
  summarise(total_exports_usd = sum(usd, na.rm = TRUE), .groups = "drop")

# 3. Save the Clean Panel for Stata
dir.create("../../data/cleaned/exports/annual/", recursive = TRUE, showWarnings = FALSE)
output_path <- "../../data/cleaned/exports/annual/global_china_shock_hs6.csv"

write.csv(global_shock_hs6, output_path, row.names = FALSE)

cat(">>> SUCCESS! Saved clean trade shock panel to:\n", output_path, "\n")